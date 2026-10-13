# Reproduction: assumeseparate, an element of a collection

One file, compiled alone:

```
scalac -d . repro.scala
```

Without the patch, Scala 3.9 and 3.10 both reject it; on 3.9:

```
Found:    (second : Sink^{all*.rd})
Required: Sink^{any}

Note that {any} is an exclusive capture set of the stateful type Sink^{any},
it cannot subsume a read-only capture set of the stateful type (second : Sink^{all*.rd}).
```

With the patch it compiles.
