# Reproduction: wasm-witcall

A stub-free call to a WIT import with the `witImportCall` intrinsic
([the feature doc](../wasm-witcall.md)): `Random.scala` calls WASI's
`get-random-bytes` directly, and `NonConstant.scala` passes a module name that
is not a literal. Compiled with the Scala.js backend, as for
[wasm](../../wasm/repro/README.md):

```
scalac -scalajs -cp $SJS Random.scala
scalac -scalajs -cp $SJS NonConstant.scala
```

With the patch, `Random.scala` compiles (the call is lowered to a WIT import
whose module and function name are in `Random$.sjsir`), and `NonConstant.scala`
is rejected: `The module name passed to witImportCall must be a String literal.`
Upstream treats `witImportCall` as an ordinary method: both compile, and the
call would only fail at link or run time.

`test.sh` is its executable form, run by `bin/proscala-test`.
