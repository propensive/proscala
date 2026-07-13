# Guard against cyclic LazyRef graphs in capture-checking Setup

Prevents an unbounded recursion (stack overflow) in the capture-checking Setup phase when its type map encounters a cycle of `LazyRef` types, by tracking which `LazyRef`s are currently being mapped and returning a re-entered one unmapped.

## Context

Capture checking runs in two stages. Before `CheckCaptures` does the actual checking, the **Setup** phase (`compiler/src/dotty/tools/dotc/cc/Setup.scala`) rewrites the types of every definition into "capture-checked form": it adds capture sets to capability types, expands throws-aliases, and converts function types into dependent functions where needed. The workhorse is `SetupTypeMap`, a `TypeMap` that recursively walks the structure of each type and transforms it.

A **`LazyRef`** (`core/Types.scala`) is a placeholder type wrapping a thunk `Context => Type`. The compiler inserts one wherever a type must refer to something that cannot be computed yet — typically recursive references, such as an F-bounded type parameter whose bound mentions the parameter itself, or mutually recursive definitions being completed. The referenced type is computed on first `ref` access and memoized. Because `LazyRef`s exist precisely to *break* cycles during type completion, a graph of `LazyRef`s can legitimately be cyclic: forcing one may lead back to itself.

`SetupTypeMap` handles a `LazyRef` with `mapConserveSuper`, which **eagerly forces** the underlying type (`t.superType`) and maps it, returning the original proxy only if nothing changed. Eager forcing is exactly what `LazyRef` exists to avoid.

## The problem

If the `LazyRef` graph reachable from a definition's type contains a cycle, `SetupTypeMap` recurses without bound: mapping the `LazyRef` forces and maps its underlying type, which contains the same `LazyRef`, which is forced and mapped again, and so on until the compiler dies with a `StackOverflowError` (or appears to hang).

In a single clean run, Setup rarely sees such cycles, because completed types have usually been simplified past their `LazyRef`s. But when a compilation unit is **suspended and re-run** — which happens whenever a macro needs a definition from the same run — denotations created in the first attempt survive into the re-run, and types reached through them can still contain live, mutually referring `LazyRef`s. Capture checking the re-run unit then walks straight into the cycle. The recursive-type shape that produces the cycle is ordinary Scala:

```scala
import language.experimental.captureChecking

// F-bounded recursion: the bound of T refers to T itself, so the
// compiler models the reference with a LazyRef while completing it.
trait Ordered[T <: Ordered[T]]:
  def compare(other: T): Int

class Version extends Ordered[Version]:
  def compare(other: Version): Int = 0
```

Combine such a type with a macro expansion (e.g. typeclass derivation) that suspends the unit, and the capture-checking Setup of the re-run recursed forever.

## The solution

The patch makes the `LazyRef` case of `SetupTypeMap` re-entrancy-safe with a visited set. Each `LazyRef` is recorded in `mappingLazyRefs` before its underlying type is forced and mapped, and removed afterwards (in a `finally`, so errors do not poison the set). If the map encounters a `LazyRef` that is already being mapped — i.e. the traversal has come full circle — it returns the `LazyRef` **unmapped**.

This is correct because returning the proxy itself loses nothing: a `LazyRef`'s underlying type is transformed anyway when it is eventually forced in a context outside this traversal, so the capture-set rewriting still happens — just lazily, the way `LazyRef` is designed to work. Only the cycle-closing edge is skipped; every other occurrence of the same `LazyRef` elsewhere in the program is still mapped normally, since the set is scoped to the active traversal. `TypeVar`, previously handled by the same case, keeps its old eager behaviour, as type variables cannot form such cycles.

## Code

The guard, added to `SetupTypeMap`:

```scala
// Guards against cyclic `LazyRef` graphs: `mapConserveSuper` forces a LazyRef's
// underlying type eagerly, and a reference cycle (reachable e.g. through denotations
// surviving a compilation-suspension re-run) would otherwise recurse without bound.
protected val mappingLazyRefs = util.HashSet[Type]()
```

And in `innerApply`, the single `case t: (LazyRef | TypeVar)` is split so that only `LazyRef` gets cycle protection:

```scala
case t: LazyRef =>
  if mappingLazyRefs.contains(t) then t   // cycle: return unmapped
  else
    mappingLazyRefs += t
    try mapConserveSuper(t) finally mappingLazyRefs.remove(t)
case t: TypeVar =>
  mapConserveSuper(t)
```

## Relevance to Soundness

Soundness compiles its entire library ecosystem with capture checking and leans heavily on macro-based typeclass derivation (Wisteria), so the triggering combination — recursive types plus macro expansions that suspend and re-run compilation units — is routine rather than exotic. A representative shape from the Soundness sources is the recursive ADT with derived typeclasses in `/Users/propensive/work/soundness/lib/wisteria/src/test/wisteria_test.scala`:

```scala
enum Tree derives Presentation, Eq:
  case Leaf
  case Branch(value: Int, left: Tree, right: Tree)
```

Deriving `Presentation` and `Eq` for `Tree` runs Wisteria's macros over a self-recursive type; under capture checking, the suspension re-runs this induces are exactly the situation in which Setup previously met a live `LazyRef` cycle and overflowed the stack.
