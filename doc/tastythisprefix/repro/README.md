# Reproduction: tastythisprefix

One file, no flags: a class with a local `inline def` which reads two of the
class's constructor parameters.

```
scalac -d a Encoder.scala                                   # compiles
scalac -from-tasty -d b -classpath a a/app/Encoder.tasty    # fails without the patch
```

Without the patch — on upstream 3.3.7 and 3.10.0 alike — the second command
fails, once for each parameter:

```
-- [E173] Reference Error: Encoder.scala:11:17
11 |      sum += word(x)
   |             ^^^^^^^
   |value raster cannot be accessed as a member of (Encoder_this : (Encoder.this : app.Encoder)) from class Encoder.
   |  private value raster can only be accessed from class Encoder in package app.
   |Inline stack trace
   |This location contains code that was inlined from Encoder.scala:5
 5 |    inline def word(x: Int): Int = raster(x.min(width - 1))
   |                                   ^^^^^^
```

With the patch the class recompiles, to the bytecode the source compilation gave.
