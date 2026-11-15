# Reproduction: tastyattrs

One file. `Box.scala` has a given alias, which the fork keeps as a cached lazy
val when capture checking is on anywhere in the run (see `givencache`), and
`Show` prints whether the class has the alias's cache field.

```
F="-experimental -language:experimental.captureChecking"
scalac $F -d a Box.scala
scala -classpath a app.Show                                       # cached
scalac -experimental -from-tasty -d b -classpath a a/app/Box.tasty a/app/Show.tasty
scala -classpath b app.Show                       # cached with the patch; uncached without
```

The second compilation leaves the capture-checking option out, as a tool which
recompiles from TASTy may. The TASTy of `Box` records that it was compiled with
capture checking (its `captureChecked` attribute), so with the patch the unit is
recompiled as it was compiled, and `javap -p` shows the same members for the
classes in `a` and `b`. Without the patch the alias becomes a plain method;
given the option again, the recompilation agrees with the source compilation
either way.

Stock Scala does not keep the alias cached from source in the first place, so
there both runs print `uncached`.
