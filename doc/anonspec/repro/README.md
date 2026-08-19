# Reproduction

    scalac crash.scala

No flags needed. Unpatched, the compiler crashes during `firstTransform`:

    java.util.NoSuchElementException: None.get
      at dotty.tools.dotc.transform.Specialization$.anonymousClassIsSpecialized

Patched, it compiles with only the expected anonymous-class-duplication
warning. The three necessary ingredients: an anonymous class, inside an
inline method, extending a parent whose constructor has a second (here
`using`) argument list.
