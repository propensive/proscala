# Context-result closures are level-checked at the method's level

Fixes capture-checking level errors in methods whose result type is a stack of context functions, by treating the compiler-generated closures that implement that stack as belonging to the method itself.

## Context

Scala 3's *capture checking* (`language.experimental.captureChecking`) tracks which *capabilities* — values like file handles, `CanThrow` evidence, or raise tactics — a value retains. A type like `(x: CT[Ex]^) ?=> Unit` is a *context function*: a function whose parameter is passed implicitly. Context functions are the standard way to thread capabilities through a program, and methods often *return* them, sometimes several deep: `def f(): A^ ?=> B^ ?=> Int`.

To keep capabilities from escaping their scope, the capture checker assigns every capability a *level* — essentially, the symbol (method, closure, class) it is bound in. A capture set belonging to some scope may only contain references whose level encloses that scope. Fresh ("root") capabilities in a method's result type are checked at the method's level.

One more piece of background: when a method's result type is a chain of context functions, the typer elaborates its body into a chain of nested anonymous closures — one per `?=>` layer. Later, erasure (`ContextFunctionResults`) *flattens* those closures away, splicing their parameters directly into the method's own parameter list. So at runtime there is no nesting at all: the parameters of every layer are just parameters of the method.

## The problem

Capture checking runs *before* erasure, and it level-checked each generated closure against its own anonymous-function symbol. A reference bound in an *outer* layer of the chain, used from an *inner* layer's body, therefore appeared to cross a scope boundary — and the method-result fresh capability rejected it:

```
Reference `contextual$1` is not included in the allowed capture set {any}
of an enclosing function literal ...
where: any is a root capability in the result type of method f
```

Minimal reproduction (from the previously-neg test `tests/pos-custom-args/captures/erased-methods2.scala`):

```scala
import language.experimental.captureChecking

class CT[-E <: Exception] extends caps.ExclusiveCapability

def Throw[Ex <: Exception](ex: Ex)(using CT[Ex]^): Nothing = ???

class Ex2 extends Exception; class Ex3 extends Exception

// error: the body uses x$1 (bound by the OUTER ?=> layer)
// from inside the INNER ?=> layer
def foo9a(i: Int): (x$1: CT[Ex3]^) ?=> (x$2: CT[Ex2]^) ?=> Unit =
  (x$1: CT[Ex3]^) ?=> (x$2: CT[Ex2]^) ?=> Throw(new Ex3)
```

The equivalent method with a *single* context-function layer compiled fine, so the error was purely an artifact of how the checker modelled the nesting — nesting that erasure removes anyway.

## The solution

Since erasure makes every layer's parameters into method parameters, the sound and consistent choice is to level-check them as method-level from the start. The patch does exactly that, in two steps:

1. When `CheckCaptures.recheckDefDef` visits a (non-anonymous) method, it walks the method body's closure chain, taking exactly `ContextFunctionResults.contextResultCount(sym)` layers — the same count erasure will flatten — and records each anonymous closure symbol against the method in a new map, `CCState.contextResultClosures`.
2. `Capability.acceptsLevelOf`, the level check, consults that map: if a reference's level owner is one of these registered closures, it is treated as if its level owner were the method itself.

This aligns level checking with post-erasure reality; no capability actually escapes, because after flattening the "inner" body and the "outer" parameter live in the same frame. The test `erased-methods2.scala` moves from `neg` to `pos` (its header already noted it "was a neg test before" — it encoded this known limitation, mirroring the safer-exceptions stacked-`CanThrow` pattern).

## Code

Registration in `compiler/src/dotty/tools/dotc/cc/CheckCaptures.scala` (`recheckDefDef`):

```scala
def registerContextResults(rhs: Tree, n: Int)(using Context): Unit =
  if n > 0 then rhs match
    case Block(List(anonDef: DefDef), _: Closure) =>
      ccState.contextResultClosures(anonDef.symbol) = sym
      registerContextResults(anonDef.rhs, n - 1)
    case Block(_, expr) => registerContextResults(expr, n)
    case Inlined(_, _, expansion) => registerContextResults(expansion, n)
    case Typed(expr, _) => registerContextResults(expr, n)
    case _ =>
if !sym.isAnonymousFunction then
  registerContextResults(tree.rhs, ContextFunctionResults.contextResultCount(sym))
```

Lookup in `compiler/src/dotty/tools/dotc/cc/Capability.scala` (`acceptsLevelOf`):

```scala
val refLevel = ref.levelOwner
val adjustedLevel = ccState.contextResultClosures.lookup(refLevel) match
  case meth: Symbol => meth
  case null => refLevel
ccOwner.isContainedIn(adjustedLevel.widenOwner(skipModules = true))
```

The map itself lives in `compiler/src/dotty/tools/dotc/cc/CCState.scala` as `contextResultClosures: EqHashMap[Symbol, Symbol]`, so it is scoped to a capture-checking run.

## Relevance to Soundness

Soundness threads capabilities almost exclusively through context functions, and hit this exact class of failure. `lib/contingency/src/core/contingency_core.scala` documents the workaround it was forced into for `safely`/`unsafely`: their block parameters supply `Diagnostics`, the tactic, and `CanThrow` in a *single* context-function layer, because — as the comment there records — "a curried `Unsafe ?=> … ?=> success` block was rejected wherever the argument was a `raises`-typed expression"; a second `?=>` layer closing over the outer layer's scoped tactic "cannot be reconciled with the block's expected type". With this patch, references bound by an outer context-function layer are valid inside inner layers, removing the need to collapse layers in such APIs (e.g. also `exoskeleton`'s `execute(block: (erased effectful: Effectful) ?=> Invocation ?=> Exit)`).
