# Reproduction: javaenumctor

No flags. `e3.scala` defines an enum which extends `java.lang.Enum`, and a main
method which, besides using the enum, calls the static `java.lang.Enum.valueOf`.

```
scalac -d a e3.scala
scalac -from-tasty -d b -classpath a 'a/e3$package.tasty' a/e3.tasty a/Color.tasty
scalac -from-tasty -d d -classpath a a/Color.tasty 'a/e3$package.tasty' a/e3.tasty
scala -classpath b e3                                       # Red, then Green
```

Without the patch the first recompilation, which reads the user of the enum
before the enum, fails:

```
-- Error: e3.scala:1:19
1 |enum Color extends java.lang.Enum[Color]:
  |                   ^^^^^^^^^^^^^^^^^^^^^
  |wrong number of arguments at <no phase> for (x$0: String, x$1: Int): Enum[Color]: (x$0: String, x$1: Int): Enum[Color], expected: 2, found: 0
```

and the second, with the enum first, succeeds. With the patch both succeed.

The order is not what matters, nor TASTy: what matters is whether
`java.lang.Enum.valueOf` is resolved before the enum's parent. From source, with
`Lookup.scala` (which calls `valueOf`) before `Color.scala` (the enum):

```
scalac -d c Lookup.scala Color.scala
-- Error: Color.scala:1:19
  |not enough arguments for constructor Enum in class Enum: (x$0: String, x$1: Int): Enum[Color]
```

Given in the other order, the same two files compile. Upstream 3.10.0 behaves
the same.
