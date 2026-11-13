# Reproduction: matchopaque, through an ordinary alias

One file, no flags, a single compilation:

```
scalac repro.scala
```

`mini.O` is an opaque type with inline extension methods, and `export mini.O`
gives it a second name, `minipkg.O`, which is an ordinary alias. Without the
patch — upstream 3.9.0 and 3.10.1 alike — a receiver whose type names the
opaque type through that alias *below the top of the type* is rejected:

```
-- [E050] Type Error: repro.scala:19:49
19 |  def refined(o: O { type Form = Int }): Int = o.next
   |                                               ^^^^^^
   |                                               expression does not take parameters
   |This location contains code that was inlined from repro.scala:10
10 |    inline def next: Int = o + 1
```

With the patch the file compiles.

| receiver's type | without the patch |
|---|---|
| `O { type Form = Int }` (alias under a refinement) | **fails** |
| `List[O]` (alias as a type argument) | **fails** |
| `O` (alias at the top: `widenDealias` follows it) | compiles |
| `mini.O { type Form = Int }` (no alias) | compiles |

An error in inlined code is reported once per inline method and file, so with
both failing lines present only one of them shows at a time.

Under capture checking the same uncast receiver shows instead as a mismatch
against the underlying type (`Found: (i : O in (xs : List[Int]))`, `Required:
Int`); `tests/pos-custom-args/captures/opaque-inline-export-alias.scala` in the
patch covers that form. `repro.scala` is the patch's
`tests/pos/opaque-inline-export-alias.scala`.
