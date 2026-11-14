# Recognise the prefix of an inline call by its class, not by type equality

Lets a class with a local inline method that reads the class's private members recompile from its TASTy, where the inlined body was refused access to them through a `this` proxy.

## Context

The body of an inline method is written inside some class `C`, and may refer to
`C.this`. Where the method is expanded, `this` may be something else, so the
inliner binds the reference to a **proxy**: a local `val C_this = <the call's
prefix>`, and every `C.this` in the body becomes `C_this`.

There is one case in which no proxy is wanted: the reference is the prefix of
the call itself, and the call is made inside `C`. Then `C.this` means in the
expansion exactly what it meant in the body, and is left as it is.

```scala
protected def canElideThis(tpe: ThisType): Boolean =
  inlineCallPrefix.tpe == tpe && ctx.owner.isContainedIn(tpe.cls)
  || ...
```

Leaving it is not only tidier. A *private* member of `C` can be selected from
`C.this`, but not from a value `C_this`, even one whose type is `C.this.type`:
the access rule for a private member asks for a `this` prefix. So for a
**local** inline method that reads private members of its class — a small helper
over the class's own fields, called in a loop — the proxy makes the expansion
ill-typed.

The test above compares two types for equality. `inlineCallPrefix.tpe` is
`cls.thisType`, the one `ThisType` the class's symbol holds. `tpe` comes from
the body. Compiled from source, the body's `C.this` *is* that same object, and
the comparison succeeds. Read from TASTy, a `ThisType` is rebuilt from the type
reference written in the file, which need not be the reference the symbol
holds: the two are then the `this` of one class, and unequal.

So the class compiled from source and did not recompile from its own TASTy.
Soundness's `hallucination` has this shape in its WebP encoder
(`Vp8Encoder.Encoder.rgbToYuv`), one of the nine components out of 305 that did
not recompile.

## Reproduction

[`repro/`](repro/) — one file, no flags:

```scala
final class Encoder(raster: Array[Int], width: Int):
  def total(): Int =
    inline def word(x: Int): Int = raster(x.min(width - 1))

    var sum = 0
    var x = 0
    while x < width do
      sum += word(x)
      x += 1
    sum
```

```
scalac -d a Encoder.scala                                   # compiles
scalac -from-tasty -d b -classpath a a/app/Encoder.tasty

-- [E173] Reference Error: Encoder.scala:11:17
   |value raster cannot be accessed as a member of (Encoder_this : (Encoder.this : app.Encoder)) from class Encoder.
   |  private value raster can only be accessed from class Encoder in package app.
```

## Solution

`ThisType` already has the comparison that is meant, `sameThis`, which compares
the classes; the access rule itself uses it. The inliner
(`inlines/Inliner.scala`) now uses it too:

```scala
protected def canElideThis(tpe: ThisType): Boolean =
  isCallPrefix(tpe) && ctx.owner.isContainedIn(tpe.cls)
  || ...

private def isCallPrefix(tpe: ThisType): Boolean = inlineCallPrefix.tpe match
  case pre: ThisType => pre.sameThis(tpe)
  case pre => pre == tpe
```

Where the prefix is not a `this` at all, the comparison is as it was. For code
compiled from source nothing changes, since equal types are the same `this`; the
recompiled class has the bytecode the source compilation gave.

A more general remedy would be for the unpickler to build every `ThisType` from
the class symbol's own type reference. That would change a type every reader of
TASTy sees, for the sake of one comparison, so it is not attempted here.

## Upstream

Upstream fails identically in both published versions tried, 3.3.7 and 3.10.0.
The patch is always on: it only makes a rejected input accepted. Worth reporting
upstream with the reproduction.

`tests/pos/local-inline-private-param-from-tasty.scala` is the reproduction as a
test; it shows the fault only when recompiled from its TASTy.
