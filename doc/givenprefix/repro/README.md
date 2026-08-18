# Reproduction: givenprefix

Two probes against the same library file, no special flags. The bug has two
polarities, so each probe expects the *opposite* outcome from the other.

The legitimate program — chained cons must construct the opaque `Lst`:

```
scalac -d out lib.scala use.scala
```

Without the patch this fails (on both streams, and on stock Scala 3.7.4 and
3.8.3):

```
-- [E007] Type Mismatch Error: use.scala:6 -------------------------------------
  |  val chained: Lst[Int] = 1 :: 2 :: Nul
  |                          ^^^^^^^^^^^^^
  |                          Found:    List[Int]
  |                          Required: minirepro.Lst[Int]
```

— the outer `::` resolved to the underlying `sci.List`'s member instead of the
extension, because the inner extension application's result kept a transparent
(package-object `this`-prefixed) view of the opaque type. With the patch it
compiles.

The leak probe — the underlying type's members must *not* be visible:

```
scalac -d out lib.scala leak.scala
```

Without the patch this compiles: `(2 :: Nul).length` selects `length` on the
underlying `scala.collection.immutable.List`, straight through the opaque
wall. With the patch it fails as it always should have:

```
-- [E008] Not Found Error: leak.scala:6 ----------------------------------------
  |  val leak = (2 :: Nul).length  // member of the underlying sci.List
  |             ^^^^^^^^^^^^^^^^^
  |             value length is not a member of minirepro.Lst[Int]
```

Derived by reduction from proscenium's opaque `List` and its `consConstructor`
given (soundness#1809); the explicit call `consConstructor.::[Int](Nul)(2)`
never leaked, which is what isolated the implicit-search path.
