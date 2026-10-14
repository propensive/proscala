# Reproduction: wasm

The component from [the feature doc](../wasm.md) — an imported host function, and
an exported `wasi:cli/run` implementation — compiled with the Scala.js backend
against the distribution's Scala.js libraries (all in its `lib/`):

```
SJS=lib/scala3-library_sjs1.jar:lib/scalajs-library_2.13-*.jar:lib/scalajs-scalalib_2.13.jar
scalac -scalajs -cp $SJS Component.scala
scalac -scalajs -cp $SJS NotFinal.scala
```

With the patch, `Component.scala` compiles to Scala.js IR in which `Host.log` is a
WIT import of `example:host/utils@0.1.0` (the module name is in `Host$.sjsir`),
and `NotFinal.scala` is rejected early: `@WitRecord class must be final.` Upstream
compiles both without complaint, and its IR has no WIT import — `Host.log` is an
ordinary method calling `wit.native` — so no component could be linked from it.

The distribution's `scalajs-scalalib_2.13.jar` is checked too: in its IR,
`scala/collection/mutable/ArrayBuilder$`, `Buffer$` and `IndexedBuffer$` must
pick their Wasm or JS implementation through the link-time property
`core/isWebAssembly` (`strings` on the `.sjsir` finds it). A scalalib built
without those guards still compiles everything, but a Wasm-only link of it fails
with `Uses JS interop with a Wasm-only module kind` through `ArrayBuilder.makeForJS`
and `js.WrappedArray` (propensive/proscala#71).

Linking an actual component needs the scala-wasm linker, which is outside the
compiler; this checks what the compiler contributes. `test.sh` is its executable
form, run by `bin/proscala-test`.
