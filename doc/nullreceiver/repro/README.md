# Reproduction: nullreceiver

Compile `repro.scala` with:

```
scalac -Yexplicit-nulls -Ycc-new repro.scala
```

Without the patch, the JVM backend tries to emit an invocation with `Null` as
the receiver class and crashes on the `BTypeLoader` assertion:

```
Cannot create ClassBType for special class symbol Null
```

With the patch, the file compiles to an ordinary `Object`-based invocation.

The first function is the snippet from [the feature doc](../nullreceiver.md),
but on its own it does not crash stock 3.9.0: explicit-nulls flow typing does
not narrow `x` to `Null` in the `else` branch. The second, `describeNull`,
whose receiver is statically `Null`, does (as does `null.hashCode`, upstream's
scala/scala3#27093). `-Ycc-new` is not needed for the crash; only
`-Yexplicit-nulls` is.
