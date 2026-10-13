# Reproduction: refinealias

One file, compiled alone:

```
scalac -d . repro.scala
```

Without the patch (Scala 3.10.0):

```
Found:    Streamable{type Self = (Res^'s1)^{any}}
Required: Streamable{type Self = Res^{r}}

Note that capability `r` cannot flow into capture set {any}.

The error occurred for a synthesized tree:  Res.streamable[Res]
```

With the patch it compiles, as it does on 3.9.
