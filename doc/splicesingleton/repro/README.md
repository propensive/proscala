# Reproduction: splicesingleton

Compile the macro, then its use, in separate runs:

```
scalac Macro_1.scala
scalac -cp . Test_2.scala
```

Without the patch, the second run fails:

```
Found:    Path^{io}
Required: (path : Path^{io})^{path}
```

With the patch, both compile. `PureMacro_3.scala` and `PureTest_4.scala` are
the same shape with a pure bound on the type parameter, `T <: Pure`, and a
value that captures `io`: with the patch the value is still rejected, with
`does not conform to upper bound Pure`. The same call with `path` a method parameter
compiles either way; so does one where the macro is replaced by a plain
method call.
