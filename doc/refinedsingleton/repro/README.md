# Reproduction: refinedsingleton

One file, with capture checking (the language import) and `-experimental`. A
tracked value is given where a refinement of its type which mentions that same
value is expected: as a result, and as an argument.

```
scalac -experimental repro.scala
```

Without the patch — upstream 3.9.0 and 3.10.0, and the fork up to 1.1.2,
alike — both are rejected:

```
-- [E007] Type Mismatch Error: repro.scala:8:77
8 |def same(reader: Reader^): (Reader { type Topic = reader.Topic })^{reader} = reader
  |                                                                             ^^^^^^
  |        Found:    (reader : app.Reader^{any})
  |        Required: app.Reader{type Topic = reader.Topic}^{reader}
  |
  |        Note that capability `any` cannot flow into capture set {reader}.
```

and for the argument, `Required: app.Reader{type Topic = reader.Topic}^{any²}`.
With the patch the file compiles. Without the language import it compiles on
any compiler: `reader.type <: Reader { type Topic = reader.Topic }` holds.

Under separation checking as well, `argument` is rejected for another reason,
and rightly: `reader` is passed twice, once where it is hidden. The test the
patch adds, which is compiled with separation checking, leaves it out.
