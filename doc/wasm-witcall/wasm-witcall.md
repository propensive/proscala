# `witImportCall`: stub-free WIT imports

A compiler intrinsic, `scala.scalajs.wit.witImportCall`, that lowers directly to a Wasm Component Model import invocation, so code generators can call imported WIT functions without hand-written `@WitImport` facade methods.

Branch: `feature/3.9/wasm-witcall`, based on `feature/3.9/wasm` (the WIT/WASM support feature, not `make`).

## Context

The Wasm Component Model describes a component's interface in WIT (Wasm Interface Type) files: named functions grouped into interfaces like `wasi:random/random@0.2.0`, with a rich type language (records, variants, resources, `list`, `tuple`, `option`, `result`). The `feature/3.9/wasm` base branch lets Scala call such imports, but only through a *facade*: a method annotated `@WitImport("module", "name")` with body `wit.native`, whose Scala signature the backend translates into the import's WIT signature. That works for hand-written bindings, but a code generator (such as Xenophile, which resolves WIT files at compile time via macros) would have to synthesize whole annotated classes just to make one call.

An *intrinsic* is a function the compiler recognizes by symbol and lowers specially: the call never executes as ordinary code; the backend consumes it at compile time and emits something else. `witImportCall` is such an intrinsic — a single call expression that carries everything needed (module, name, signature, arguments) and lowers to the same Component Model import invocation as an `@WitImport` method call.

## What the feature provides

The library side is `library-js/src/scala/scalajs/wit/package.scala`:

```scala
def witImportCall(module: String, name: String, sigAndArgs: Any*): Any = native
```

`module` and `name` must be constant `String` literals. `sigAndArgs` is a flat inline varargs list:

```scala
classOf[R], <wit-result-type>, classOf[P0], arg0, classOf[P1], arg1, ...
```

The result carrier comes first as `classOf[R]` (or `classOf[Unit]`), giving the erasure-safe IR result type. Because `classOf` erases nested type arguments — `list<tuple<string, string>>` would reach the linker as a fieldless tuple — the *WIT* result type is carried separately as a **structured descriptor**: a tree of never-evaluated marker functions `witPrim`, `witNamed`, `witList`, `witTuple`, `witOption`, `witResult`, `witUnit`. `witNamed(classOf[X])` delegates to the existing `toWIT` derivation, so records, variants, flags, enums and resources can appear in result positions. A parameter slot is normally a bare `classOf[P]`, but may be `witParam(classOf[P], <descriptor>)` when the WIT type needs more than erasure can carry (e.g. `option<string>`). The caller casts the `Any` result to the real type.

For example, the vendored WASI binding `getRandomBytes` (WIT: `get-random-bytes: func(len: u64) -> list<u8>`) could equally be invoked stub-free:

```scala
import scala.scalajs.wit.*

val bytes = witImportCall(
  "wasi:random/random@0.2.0", "get-random-bytes",
  classOf[Array[unsigned.UByte]], witList(witPrim("u8")),
  classOf[unsigned.ULong], len
).asInstanceOf[Array[unsigned.UByte]]
```

The intrinsic is intended for macro-emitted code, not to be written by hand. Because macros deliver literals wrapped in adaptation nodes (`Typed`, trivial blocks), the backend unwraps these before matching.

The branch also vendors scala-wasm's generated WASI 0.2.0 facades (`library-js/src/scala/scalajs/wasi/**`: io, cli, filesystem, sockets, http, random, clocks) so the `@WitResourceImport` resource traits and `@WitRecord`/`@WitVariant` named types exist for code — including macro-emitted code — that works with WIT resources.

## How it works

In `JSCodeGen` (with support in `JSDefinitions` and `WitCodeGen`), `genWitImportCallPrimitive` recognizes the call by symbol, recovers the constant module/name strings and the `classOf` literals, and converts the descriptor tree to an IR `ValType` by matching the `wit*` marker symbols — no text parsing. It then synthesizes a `WitNativeMemberDef` on the enclosing class (deduplicated across identical imports in a per-class `LinkedHashMap`, flushed into the class's `witNativeMembers`) and emits a `WitFunctionApply` keyed by the same synthetic method name — exactly the lowering used for an `@WitImport` method call. A small robustness fix makes `toWIT` sort `@WitVariant` cases by declaration order rather than source span when symbols come from Tasty (the vendored facades have no spans).

## Code

A vendored WASI facade, showing the annotation-based path the intrinsic bypasses (`library-js/src/scala/scalajs/wasi/random/random.scala`):

```scala
@scala.scalajs.wit.annotation.WitImport("wasi:random/random@0.2.0", "get-random-bytes")
def getRandomBytes(
    len: scala.scalajs.wit.unsigned.ULong): Array[scala.scalajs.wit.unsigned.UByte] = {
  scala.scalajs.wit.native
}
```

And a structural parameter slot (`library-js/src/scala/scalajs/wit/package.scala`):

```scala
/** A parameter-type slot of `witImportCall` whose WIT type needs more than
 *  `classOf` can carry (e.g. `option<string>`) ... */
def witParam(cls: Class[?], descriptor: Any): Any = native
```

## Relevance to Soundness

Xenophile, the Soundness WIT/Component Model library, is the intended emitter. The end-to-end test at `/Users/propensive/work/xenophile-wasm-e2e/e2e/src/main/scala/Main.scala` resolves a WIT interface from the classpath and calls an import with no facade — the `invoke` macro expands to `witImportCall`:

```scala
type RandomApi = Interface in Wit at "/wasi/random.wit"
given RandomApi = Interface[Wit](cp"/wasi/random.wit")

val n: U64 = Foreign["random", Wit].`get-random-u64`().invoke[U64]
```

The backtick identifier keeps the kebab-case WIT name faithful all the way through to `witImportCall`.
