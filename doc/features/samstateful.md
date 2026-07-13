# Read-only views of constant method-result capture sets

Allows a constant capture set consisting only of method-result capabilities to be adapted to read-only, fixing spurious mutability errors when a SAM literal over a stateful-returning method is expanded to an anonymous class (as happens under `-scalajs`).

## Context

Capture checking tracks, in the type of every value, the set of capabilities the value retains — its *capture set*, written `T^{a, b}`. Mutation tracking refines this: a type extending `caps.Stateful` is a stateful capability, and each of its capabilities is either *exclusive* (permits mutation, e.g. calling `update` methods) or *read-only* (written `x.rd`). A read-only capability conforms to nothing exclusive: when the checker must reconcile a read-only set with an exclusive one, `adaptMutability` asks the exclusive (writer) set to downgrade itself via `toReader()`.

Capture sets come in two flavours in the compiler: `Var`s, which are inference variables that can still grow and record state changes, and `Const`s, which are fixed. A `Var` implements `toReader()` by mutating its recorded mutability to `Reader`. A `Const` has nowhere to record that, and before this patch failed unconditionally with a `MutAdaptFailure`.

One further piece: the result type of a method like `def make(): Buffer^` does not capture any *particular* capability — its `^` is an existential, represented by a `ResultCap` (or a `LocalCap` localised from `caps.any` whose origin is the method declaration). It stands for "whatever the concrete result of this method captures".

## The problem

```scala
import caps.*

class Buffer extends Mutable:
  update def write(b: Byte): Unit = ()

trait Maker:
  def make(): Buffer^        // result capability is an existential ResultCap

val maker: Maker = () => Buffer()   // SAM literal
```

On the JVM this compiles: the SAM literal stays a closure whose result carries a fresh mutable capability held in a `Var`, and `toReader()` succeeds by mutating that `Var`. Under `-scalajs`, however, `isSam` rejects arbitrary traits, so the literal is expanded to an anonymous class *before* capture checking. The synthetic override of `make` is then checked against the inherited method, whose result capability is the constant set `{ResultCap}`. When `adaptMutability` needs a read-only view of that constant set, `Const.toReader()` fails, and compilation aborts with a mutability-adaptation error — for code that is perfectly sound and accepted on the JVM.

## The solution

`Const.toReader()` now succeeds when the set is non-empty and *every* element is a method-result root: a `ResultCap`, or a `LocalCap` whose origin is a method declaration (`Origin.InDecl` with a `Method` symbol). Such a capability occurs only in covariant result position and denotes whatever the concrete result captures, so a read-only result conforms to it — the constant set can be *viewed* read-only without recording anything. This is exactly the conclusion the JVM path reaches through the equivalent fresh `Var`.

The relaxation is deliberately narrow. It does not apply to a genuine exclusive requirement such as `caps.any` in a *value* type ascription — there the origin is a value, not a method, and widening an empty or read-only capture remains an error (the `mut-widen-empty` test). The full `neg-custom-args/captures` suite (223 expected-error tests) accepts nothing new.

## Code

From `compiler/src/dotty/tools/dotc/cc/CaptureSet.scala`, in `class Const`:

```scala
def toReader()(using Context) =
  def isMethodResultRoot(elem: Capability): Boolean = elem.core match
    case _: ResultCap => true
    case lc: LocalCap => lc.origin match
      case Origin.InDecl(sym, _) => sym.is(Method)
      case _ => false
    case _ => false
  if !elems.isEmpty && elems.forall(isMethodResultRoot) then true
  else failWith(MutAdaptFailure(this))
```

Previously the body was a single `failWith(MutAdaptFailure(this))`. The `LocalCap` case handles `caps.any` localised into a method declaration; the empty-set guard preserves the existing error for widening an empty capture.

## Relevance to Soundness

Soundness's streaming layer hits this pattern directly. `Stream` (`lib/zephyrine/src/core/zephyrine.Stream.scala`) extends `caps.ExclusiveCapability, caps.Stateful`, and the `Source` typeclass (`lib/turbulence/src/core/turbulence.Source.scala`) is a SAM whose single method returns it:

```scala
trait Source extends Typeclass, Operable:
  type Transport
  def stream(value: Self): (Stream[Operand] over Transport)^
```

Instances are routinely written as SAM literals, e.g. in `lib/zeppelin/src/core/zeppelin.Zip.scala`:

```scala
given source: Entry is Source by Data over Credit =
  entry => Stream(entry.contents.iterator)
```

Since Soundness also targets Scala.js, each such lambda is expanded to an anonymous class before capture checking, and without this patch the override of `stream` fails mutability adaptation against the inherited constant `ResultCap`.
