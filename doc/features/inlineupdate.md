# Propagate update classification to inline accessors

Synthetic accessors generated for private members referenced from inline methods now inherit the "update method" classification under separation checking, so inline methods that mutate private state no longer fail the exclusivity check.

## Context

Capture checking's *separation checking* mode (`-language:experimental.separationChecking`) tracks mutation of stateful objects. A class that extends `caps.Mutable`/`Stateful` declares its mutating operations as **update methods** — either methods marked with the `update` soft modifier, or setters of its mutable fields. Internally an update method carries the `Mutable` flag together with `Method`, and `cc.Mutability.isUpdateMethod` recognises it by exactly that flag combination. The checker enforces *exclusivity*: state may only be written from inside an update method (or a constructor), and only through a reference whose capture set is exclusive rather than read-only. A violation reports:

```
the access is in method X, which is not an update method
```

Separately, **inline accessors** are a plain Scala mechanism with no connection to capture checking: an `inline def` is expanded at call sites, which may lie outside the defining class, so any reference it makes to a `private` member cannot survive inlining as-is. The compiler therefore rewrites such references to synthetic public forwarders — `inline$x` to read a private field, `inline$x_=` to write it, or a call forwarder for a private method. These symbols are created in `transform/AccessProxies.scala`.

## The problem

The two features composed badly. The accessor symbol was created with only `Synthetic | Method` (plus `Final`/`Override`), so even when the member it wrapped was an update method or a mutable field's write path, the accessor itself was *not* classified as an update method. The mutation now happened textually inside the accessor's body, `isUpdateMethod` returned false for it, and the exclusivity check rejected perfectly legal code:

```scala
import language.experimental.captureChecking
import language.experimental.separationChecking

class Counter extends caps.Mutable:
  private var count: Int = 0
  private update def bump(): Unit = count += 1

  inline update def next(): Int =   // inlined at call sites outside Counter
    bump()                          // rewritten to a synthetic accessor for bump
    count                           // rewritten to inline$count
```

The reference to `bump()` is rewritten to a synthetic forwarder, and any private-var assignment reached this way to an `inline$…_=` setter. Both mutate `Counter`'s state, but neither synthetic symbol counted as an update method, so compilation failed with "the access is in method inline$…, which is not an update method" — even though `next()` itself is properly declared `update`.

## The solution

When creating an accessor symbol, `AccessProxies` now checks (only under separation checking) whether the accessed symbol is an update method (`Mutable | Method`), or a mutable field being wrapped by a setter accessor (`Mutable`, not a method, and the accessor name is a setter name). In either case the accessor gets the `Mutable` flag, which — combined with the `Method` flag it already has — makes `isUpdateMethod` true for it.

This is correct because the accessor is a pure forwarder: it performs exactly the mutation of the member it wraps, no more. Classifying it as an update method mirrors the classification of the thing it forwards to, so exclusivity is still enforced at every real call site (the caller must itself be in an update context to invoke it, and the receiver's capture set must be exclusive); the flag merely stops the checker from treating the synthetic hop as an illegal mutation site. Getter accessors for mutable fields are deliberately left unflagged: reading a `var` is not an update.

## Code

The whole patch is one guarded flag assignment in `newAccessorSymbol` (`compiler/src/dotty/tools/dotc/transform/AccessProxies.scala`):

```scala
val sym = newSymbol(owner, name, Synthetic | Method, info, coord = accessed.span).entered
if accessed.is(Private) then sym.setFlag(Final)
else if sym.allOverriddenSymbols.exists(!_.is(Deferred)) then sym.setFlag(Override)
// Under separation checking, an accessor for an update method, or a setter accessor
// for a mutable field, must itself count as an update method (see
// cc.Mutability.isUpdateMethod): otherwise any inline method that updates state
// through a private member fails the exclusivity check inside the synthetic accessor.
if Feature.enabled(Feature.separationChecking)
   && (accessed.isAllOf(Mutable | Method)
       || accessed.is(Mutable) && !accessed.is(Method) && name.isSetterName)
then sym.setFlag(Mutable)
```

The first disjunct covers forwarders to (possibly private) `update` methods; the second covers `inline$x_=` setters for mutable fields, identified by `name.isSetterName` so plain getters stay read-only.

## Relevance to Soundness

Soundness leans on exactly this combination for hot-path parsing. `zephyrine.Cursor` (`/Users/propensive/work/soundness/lib/zephyrine/src/core/zephyrine.Cursor.scala`) is a `caps.Mutable` streaming cursor whose entire navigation API is `inline update def`s over private state:

```scala
private var pos: Int = 0
...
inline update def unsafeBumpPos(by: Int)(using erased unsafe: Unsafe): Unit = pos += by

inline update def more: Boolean = pos < writeEnd || moreSlow()

private update def moreSlow(): Boolean =
  !ended && { refill(); pos < writeEnd }
```

Inlining `unsafeBumpPos` at a call site produces an `inline$pos_=` setter accessor (the patch's mutable-field case), and inlining `more` produces a forwarder to the private update method `moreSlow` (the update-method case). Without this patch, every parser hot loop built on `Cursor` — e.g. `while more && test(peek) do advance()` — was rejected by the separation checker inside the synthetic accessors.
