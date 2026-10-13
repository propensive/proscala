# Reproduction: macrosingleton

Two files, compiled separately (a macro must be compiled before its use), then run:

```
scalac -d . Macro_1.scala
scalac -cp . -d . Test_2.scala
scala -cp . repro.Test
```

Without the patch (Scala 3.10.0), `Test_2.scala` fails:

```
Macro expansion has type (repro.Unset : => (repro.opt.Unset² : repro.opt.Unset)), which does not conform to the expected type Null | String
```

With the patch it compiles, and `use` returns `null`, as on 3.9.
