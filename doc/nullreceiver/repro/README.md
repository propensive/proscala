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
The snippet is extracted verbatim from [the feature doc](../nullreceiver.md).
