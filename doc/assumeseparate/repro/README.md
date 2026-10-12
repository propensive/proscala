# Reproduction: assumeseparate

One file, compiled alone:

```
scalac -d . repro.scala
```

Without the patch (Scala 3.10.0):

```
Found:    Sink^{any.rd}
Required: Sink^{any²}

Note that {any²} is an exclusive capture set of the stateful type Sink^{any²},
it cannot subsume a read-only capture set of the stateful type Sink^{any.rd}.
```

With the patch it compiles, as it does on 3.9.
