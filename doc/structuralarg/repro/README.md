# Reproduction: structuralarg

Compile the single file with:

```
scalac repro.scala
```

Without the patch, on scala/scala3 3.10.2-RC1 or later, the compiler crashes in
the typer:

```
java.lang.ClassCastException: class dotty.tools.dotc.core.Symbols$NoSymbol$ cannot be cast to class dotty.tools.dotc.core.Symbols$ClassSymbol
	at dotty.tools.dotc.typer.Dynamic.handleRepeated$1(Dynamic.scala:195)
	at dotty.tools.dotc.typer.Dynamic.structuralCall$1(Dynamic.scala:225)
	at dotty.tools.dotc.typer.Dynamic.handleStructural(Dynamic.scala:311)
```

With the patch, the file compiles. Scala 3.10.0 and 3.10.1 compile it unpatched.

The trigger is a structural call whose argument has a type with no class
symbol: here an opaque alias bounded by an intersection of two unrelated
classes. Bounded by `Matchable` alone, the file compiles unpatched.

Reduced from Soundness's enigmatic (`crypto.ecdsa(digest.token)`, where the
token is a `Text`).
