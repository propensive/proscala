# Reproduction: matchopaque

No flags, and nothing beyond the standard library. `lib.scala` and `alias.scala`
are a library: an object with two opaque types, inline extension methods on
them, and a match-type alias `Cell[value]` that selects between them.
`use.scala` declares the same value three ways and calls the inline methods on
each. `client.scala` calls them on a value compiled separately.

```
scalac -d l lib.scala alias.scala
scalac -d a -classpath l use.scala                             # compiles

scalac -from-tasty -d b -classpath l:a a/use/Direct.tasty      # compiles
scalac -from-tasty -d b -classpath l:a a/use/Inferred.tasty    # compiles
scalac -from-tasty -d b -classpath l:a a/use/Aliased.tasty     # fails without the patch
scalac -d c -classpath l:a client.scala                        # fails without the patch
```

Without the patch — on upstream 3.3.6 and 3.10.0 alike — the last two
fail, once for each call:

```
-- [E050] Type Error: use.scala:7:26
 7 |  def read(): String = ref()
   |                       ^^^^^
   |                       expression does not take parameters
   |Inline stack trace
   |This location contains code that was inlined from lib.scala:14
14 |      inline def apply(): value = ref.get().nn
   |                                  ^^^^^^^
```

With the patch both compile, and `java -cp c:b:l:<scala library> client.Client`
prints `a a b`.

What the variants show:

| declared type of `ref` | compiled in the same run | read from TASTy |
|---|---|---|
| `Cell[String]` (match alias, reduces to `Cell.Ref[String]`) | compiles | **fails** |
| `Cell.Ref[String]` (the opaque type itself) | compiles | compiles |
| none (inferred as `Cell.Ref[String]`) | compiles | compiles |

`alias.scala` is a separate file so that the type `Cell` and the object `Cell`
are not made companions inside one `$package` wrapper.

One difference remains between the class compiled from source and the one
recompiled from TASTy, which this patch does not address: the field `ref` of
`use.Aliased$` has the generic signature `AtomicReference<String>` from source
and none from TASTy, because the unpickled declared type is still unreduced
when the signature is generated. The instructions are identical.
