# Reproduction: unionatoms

Compile `repro.scala`; the capture-checking language import is the whole
configuration:

```
scalac repro.scala
```

Without the patch, `e`, whose type is `k1.type`, does not conform to
`k1.type | k2.type`:

```
Found:    (P.e : (P.k1 : Kind^{}))
Required: (P.k1 : Kind^{}) | (P.k2 : Kind^{})
```

Without the language import the file compiles, as it does with the patch.
The singletons must be members of an object (or local to a method): unions of
objects declared directly in a package compare correctly either way.
