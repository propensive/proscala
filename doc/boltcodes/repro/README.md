# Reproduction: boltcodes

Errors of three kinds — one upstream numbers, one it does not, and two reported
by macros — which the flag labels with their bolt codes ([the feature
doc](../boltcodes.md) describes them):

```
scalac -Zbolt-codes plain.scala
scalac -Zbolt-codes stored.scala
scalac -Zbolt-codes macros.scala
scalac -Zbolt-codes -cp . coded.scala
scalac -Zbolt-codes -cp . uncoded.scala
```

With the flag, `plain.scala`'s errors are headed `[↯/p.7.40] Error` (a trait
with a secondary constructor, which upstream does not number) and `[↯/p.1.7]
Type Mismatch Error` (upstream's `E007`). `stored.scala`'s warning, which the
compiler reports as a plain string, is `[↯/p.11.21]`. The macro in `coded.scala` begins its
message with `[↯/s.87.1.2]`, and its error is headed with the compound
`[↯/p.2.2/s.87.1.2]`, the macro's own code taken out of the message text; the one
in `uncoded.scala` gives no code and is `[↯/p.2.2]`.

Without it, the headings are upstream's `-- Error:` and `-- [E007] Type Mismatch
Error:`, and the first macro's message keeps the code it was written with.

This is a feature, not a fix: there is no bug, only the labelling. `test.sh` is
its executable form, run by `bin/proscala-test`.
