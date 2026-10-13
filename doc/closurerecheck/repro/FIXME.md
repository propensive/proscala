# No self-contained reproduction yet

The failure needs a closure whose body the capture checker first reaches by
completing it on demand, and then reaches again through its closure block. In
Soundness that happens when a wisteria derivation (`Json.DecodableDerivation`)
is summoned with `summonInline` inside a closure in a separately compiled inline
method: the outer closure's body is not checked by the main traversal (see
[inlinedclosures](../../inlinedclosures/inlinedclosures.md)), and `postCheck`'s
`needsRecompute` forces a definition inside it whose owner chain runs through
the derivation's shape thunk. The irregular owners of the definitions the
wisteria macro generates are part of the trigger, and a case without the macro
has not been found.

The in-tree reproduction is apoplexy's test module in Soundness, on an
unpatched 3.10 tree:

    mill apoplexy.test.compile

fails at `apoplexy.CorpusApiTests.scala:147` with the mismatch quoted in the
feature doc. A probe as small as

```scala
case class P(id: Optional[Long])

transparent inline def attempted[value](): Attempt[value, Connect.Error] =
  contingency.attempt[Connect.Error]:
    scala.compiletime.summonInline[value is Json.Decodable]
    ???
```

compiled into one jar, and `attempted[P]()` with `strategies.throwUnsafely`
imported, compiled against it, fails the same way.
