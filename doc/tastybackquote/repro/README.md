# Reproduction: tastybackquote

One file, no flags. `use.scala` matches a value against a backquoted identifier,
once nested in a tuple pattern and once directly, and prints what the two
matches give for a value which is *not* the one named. A third match, against
`Seq(first, rest*)`, has a sequence wildcard, whose `_*` must not be taken for a
backquoted identifier.

```
scalac -d a use.scala
scalac -from-tasty -d b -classpath a a/app/Use.tasty
scala -classpath a app.Use      # -1 -1 2
scala -classpath b app.Use      # -1 -1 2 with the patch; 5 1 2 without
```

Without the patch — on upstream 3.3.7 and 3.10.0 alike — the class recompiled
from TASTy prints `5 1 2`: both patterns match a value they should reject. Nothing
is reported; only running the code shows it.

`-Vprint:pickler` on the first command shows `` case `label` => ``, and
`-Vprint:readTasty` on the second showed `case label =>` — the same tree, without
the mark that tells the two apart.
