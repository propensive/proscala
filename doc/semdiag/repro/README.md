# Reproduction: semdiag

A type mismatch involving a local value, whose diagnostic the flag turns into
structured XML ([the feature doc](../semdiag.md) describes the format):

```
scalac -Zsemantic-diagnostics local.scala
```

With the flag, the error is printed as a `<diagnostic severity="error"
kind="TypeMismatch" …>` element whose `<message>` marks each type as
`<type tasty="…">`, with a `<placeholder kind="local-term" name="b2" …>` standing
for the local value `b2`. Without it, the output is upstream's usual console
text:

```
-- [E007] Type Mismatch Error: local.scala:6:23 ----------------------------------
6 |    val b3: Box[Int] = b2
  |                       ^^
  |                       Found:    (b2 : Box[String])
  |                       Required: Box[Int]
```

A macro's message can carry markup of its own. `TreeMacro_1.scala` reports an
error whose text is a tree of two nodes, marked as one; `TreeUse_2.scala` calls
it. With the flag the tree is `<tree><node role="resolving" name="Fairy">…`,
with the node for `puck` inside the node for `Fairy`; without it, it is the
text between the markers, which draws the same tree:

```
no fairy

 ■ resolving Fairy
 └─ ▸ propose puck
```

This is a feature, not a fix: there is no bug, only the output format.
`test.sh` is its executable form, run by `bin/proscala-test`.
