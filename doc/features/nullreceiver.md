# Widen bottom-typed call receivers to Object in the backend

Prevents a compiler crash when the JVM backend emits a method call whose receiver is statically typed as `Null` or `Nothing`, by widening the invocation's receiver class to `Object`.

## Context

The last stage of the Scala 3 compiler is the JVM backend, which turns typed trees into classfile bytecode. Every non-static method call becomes an invocation instruction (`invokevirtual`, `invokeinterface`, etc.), and each such instruction names a *receiver class* in its descriptor — the JVM class against which the method is resolved at runtime. The backend computes this class in `genCallMethod` in `compiler/src/dotty/tools/backend/jvm/BCodeBodyBuilder.scala`, then asks the `BTypeLoader` for that class's bytecode-level representation (its `ClassBType`).

Scala's type system has two *bottom types* that the JVM knows nothing about: `Nothing` (no values) and `Null` (only the `null` value). They are compile-time fictions with no runtime class of their own, so `BTypeLoader.classBTypeFromSymbol` refuses to build a `ClassBType` for them — attempting it trips the assertion `"Cannot create ClassBType for special class symbol Null"` (`BTypeLoader.scala:78`) and the compiler crashes.

## The problem

Normally erasure and earlier phases ensure no call ever has a bottom-typed receiver by the time it reaches the backend. But with `-Yexplicit-nulls`, flow typing can narrow a value's type to exactly `Null` inside a branch, and in combination with capture checking (`-Ycc-new`) such a call can survive all the way to `genCallMethod`. `genCallMethod` already guarded one path — a `specificReceiver` argument is ignored if it is a bottom class — but the fallback, `method.owner`, and the erased receiver were passed straight to `classBTypeFromSymbol`.

A minimal reproduction, compiled with `-Yexplicit-nulls`:

```scala
def describe(x: String | Null): Int =
  if x != null then x.length
  else x.hashCode   // here x is flow-typed to Null; hashCode is dispatched
                    // on a receiver of class Null
```

In the `else` branch `x` has type `Null`, and `hashCode` — a universal `Any`/`Object` member — is still a legal selection. The backend then tries to emit an invocation with `Null` as the receiver class, hits the `BTypeLoader` assertion, and the compilation aborts with a crash rather than producing bytecode.

## The solution

The only members that can be selected on `Nothing` or `Null` are those inherited from `Any`, which at runtime live on `java.lang.Object`. So it is always sound to name `Object` as the receiver class in the invocation descriptor: resolution of `hashCode`, `toString`, `equals`, etc. against `Object` succeeds, and virtual dispatch still finds any override at runtime. (If the receiver is actually `null` the call throws `NullPointerException`, exactly as the language semantics require — the descriptor class does not change that.)

The patch checks the computed receiver class with `defn.isBottomClassAfterErasure` (true only for the `Nothing` and `Null` class symbols) and substitutes `defn.ObjectClass` before the `ClassBType` lookup. The interface check is also switched to the widened class, so a bottom receiver can never be misclassified and emitted as `invokeinterface`.

## Code

From `genCallMethod` in `BCodeBodyBuilder.scala`:

```scala
receiverClass.info // ensure types the type is up to date; erasure may add lateINTERFACE to traits
// A call can reach the backend with a bottom-typed receiver (e.g. a member call on a
// value flow-typed to `Null` under explicit nulls with capture checking); `Nothing`
// and `Null` have no runtime class, and the only members dispatchable on them are
// Object's, so widen the descriptor's receiver to Object.
val receiverClass1 =
  if defn.isBottomClassAfterErasure(receiverClass) then defn.ObjectClass else receiverClass
val receiverName = bTypeLoader.classBTypeFromSymbol(receiverClass1).internalName
...
val isInterface = isEmittedInterface(receiverClass1)
```

Everything downstream — the invocation opcode selection and the emitted descriptor — uses `receiverClass1`/`receiverName`, so a bottom-typed receiver now produces an ordinary `Object`-based invocation instead of a crash.

## Relevance to Soundness

Soundness is compiled with exactly the combination that triggers this: `-Yexplicit-nulls` is set globally (`build.mill`, line 106), and capture checking is being rolled out module-by-module via the `cc(options)` helper that appends `-Ycc-new` (`build.mill`, around line 123). Soundness code also does heavy null flow typing at Java-interop boundaries — for example `lib/turbulence/src/core/turbulence.Manifold.scala` matches queue results against `case null =>` and branches on `if error0 == null`, and `lib/fulminate/src/core/fulminate_core.scala` flow-types `position == null`. In branches like these, any universal-member call (`hashCode`, `toString`, logging a value) on the narrowed-to-`Null` binding sends a bottom-typed receiver into the backend, which crashed the compiler before this patch.
