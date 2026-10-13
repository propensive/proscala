# Reproduction: anonascribe

Two files, compiled separately, so that `backend`'s body reaches `Test_2.scala`
from TASTy:

```
scalac -d . Lib_1.scala
scalac -cp . -d . Test_2.scala
```

Without the patch (Scala 3.10.0), `Test_2.scala` fails:

```
Found:    Stream^{any.rd}
Required: Stream^{any²}

Note that {any²} is an exclusive capture set of the stateful type Stream^{any²},
it cannot subsume a read-only capture set of the stateful type Stream^{any.rd}.
```

With the patch it compiles, as it does on 3.9, and as both files do compiled
together in one run.
