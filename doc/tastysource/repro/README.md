# Reproduction: tastysource

One file, no flags. `main` calls an inline method which throws, and prints the
top frame of the stack trace.

```
scalac -d a Trace.scala
scalac -from-tasty -d b -classpath a a/app/Trace.tasty
scala -classpath a app.Trace     # app.Trace$.main(Trace.scala:4)
scala -classpath b app.Trace     # the same with the patch
javap -v -classpath b 'app.Trace$' | grep SourceFile
```

Without the patch — on upstream 3.10.0 too — the class recompiled from TASTy
prints

```
app.Trace$.main(Trace.tasty:1)
```

and `javap` shows `SourceFile: "Trace.tasty"`. With the patch both are as from
source: `Trace.scala:4`, and `SourceFile: "Trace.scala"`; `javap -c -l` gives the
same output for the two class files, line tables included.
