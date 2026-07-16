# Reproduction: splicealias

Two files, compiled **separately** (the macro must already be compiled when
`Use.scala` is checked):

```
scalac Macro.scala
scalac -classpath . -language:experimental.captureChecking Use.scala
```

Without the patch, capture checking's recheck compares the anonymous class's
`type Self = <binder>` (whose pickled placeholder info is `TypeAlias(Any)`)
against the expected `type Self = String` and fails with an error of the form:

```
Object with TC {...}^'s1 does not conform to TC { type Self = String }
```

followed by "object creation impossible". With the patch, both files compile.
The snippets are extracted verbatim from [the feature doc](../splicealias.md).
