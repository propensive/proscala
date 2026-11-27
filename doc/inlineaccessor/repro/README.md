# Reproduction: inlineaccessor

Compile the single file with:

```
scalac -experimental repro.scala
```

Without the patch, on scala/scala3 3.10.2-RC1 or later, both statements of
`Parser.step` are rejected:

```
-- Error: repro.scala:15:4 -----------------------------------------------------
15 |    count += 1
   |    ^
   |Separation failure: Illegal access to {Parser.this} which is hidden by the previous definition
   |of method Cursor$Snapshot$$inline$cells with result type Array[Byte]^{any.rd}.
   |This type hides capabilities  {Parser.this.rd}
```

With the patch, the file compiles. Scala 3.10.0 and 3.10.1 compile it unpatched.

The trigger is an inline method which reads a `protected` (or `private`) array
field, in a class checked with separation checking: the inliner reads the field
through an accessor it generates, and the accessor is taken for a definition
which hides the instance.

Reduced from Soundness's ypsiloid, whose YAML parser extends the inline trait
`zephyrine.Cursor.Snapshot`.
