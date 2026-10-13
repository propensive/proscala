# Reproduction: inlinedclosures

Two files, compiled separately, so that `withFile`'s body reaches `Test_2.scala`
from TASTy:

```
scalac -d . Lib_1.scala
scalac -Zcheck-inlined-closures -cp . -d . Test_2.scala
```

Without the patch (or without the flag), Scala 3.10.0 accepts `Test_2.scala`,
though `file` escapes the closure `usingFile` passes it to. Compiled with
`Lib_1.scala` in one run, the same code is rejected.

With the flag, it is rejected as it is in one run:

```
Capability `file` defined in an enclosing function outlives its scope:
it leaks into outer capture set 's1 of method test.
```
