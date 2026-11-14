# Reproduction: tastymacro

Three files, no flags: a macro (`Macro.scala`), a unit which calls it and also
declares an enum (`Use.scala`), and a unit which refers to that enum
(`Other.scala`).

```
scalac -d a Macro.scala Use.scala Other.scala
scalac -from-tasty -Xprint-suspension -d b -classpath a \
  a/app/Macro.tasty a/app/Use.tasty a/app/Other.tasty
```

Without the patch — on upstream 3.10.0 too — the second command suspends `Use`
and fails when it compiles it again:

```
-- [E120] Naming Error: Use.scala:5:9
5 |    case Expect(char: Char)
  |         ^
  |Conflicting definitions:
  |def fromProduct(p: Product): Object in object Expect and
  |def fromProduct(p: Product): Object in object Expect
  |have the same type (p: Product): Object after erasure.

compiling suspended a/app/Use.tasty
  a/app/Use.tasty at inlining: suspension triggered by macro call to method impl in object Macro in a/app/Macro.tasty
```

With the patch there is one run and no suspension, and the classes are those the
source compilation gave (`Macro$` differs in the bytes of its pickled quote, as it
does from TASTy without the patch).

`Other.scala` is what makes the second run fail: without it nothing in the first
run has referred to the enum's synthetic members, and the second run happens to
succeed, which is why a two-file reduction does not show the problem.
