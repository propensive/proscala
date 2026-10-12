# Reproduction: smap

The inline expansion from [the feature doc](../smap.md): `x + x` in `Util.scala`
is inlined into `Main.run`.

```
scalac -Zinline-source-maps Util.scala Main.scala
javap -v Main.class
```

With the flag, `Main.class` carries a `SourceDebugExtension` attribute (JSR-45
SMAP) whose `Scala` stratum maps a synthetic line of `Main` to `Util.scala:3`,
where `x + x` lives. Without it, upstream's output: every instruction of the
expansion carries line 3 of `Main.scala` (the call), and `javap -v` shows no
`SourceDebugExtension`, so a breakpoint on `x + x` can never bind in `Main`.

`test.sh` is its executable form, run by `bin/proscala-test` (it needs `javap`,
from the JDK).
