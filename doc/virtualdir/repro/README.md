# Reproduction: virtualdir

A tool that obtains an in-memory directory through the sanctioned factory,
`dotty.tools.io.virtualDirectory` ([the feature doc](../virtualdir.md)), compiled
and run against the compiler's own jar:

```
scalac -cp scala3-compiler_3.jar UseVirtualDir.scala
scala -cp scala3-compiler_3.jar:. useVirtualDir     # prints: name=scratch empty=true
```

On the 3.9 stream without the backport, compilation fails: `virtualDirectory` is
not a member of package `dotty.tools.io` (only the public `VirtualDirectory`
constructor exists there). The 3.10 line has the factory upstream, so this
compiles there unpatched.

`test.sh` is its executable form, run by `bin/proscala-test`.
