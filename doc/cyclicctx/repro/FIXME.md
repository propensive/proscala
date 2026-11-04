# FIXME: no self-contained reproduction yet

The assertion is reproduced by a real project rather than by standalone files:

- Check out propensive/soundness at `09a0acbc7c` (main, 2026-10-19) with its `build.mill` on
  Proscala 1.0.1's Scala 3.10.0 build (`3.10.0-pro-1.0.1`) and run a clean
  `./mill --no-daemon -j 6 soundness.native.compile`.
- In some of those builds (3 of 6 reported in propensive/proscala#20; 2 of 5 on 1.0.0),
  `quantitative.core.native.compile` fails with `denotation class SourceFile invalid in run 1.
  ValidFor: Period(3.1-75)` thrown from `CyclicReference.toMessage` under `Driver.doCompile`,
  and with this patch prints the cyclic reference instead — the one
  [movestatics](../../movestatics/movestatics.md) fixes.

What a standalone reproduction needs is a `TypeError` that escapes a run after typer, in a
compilation that has suspended units (so that the error's run id is above the handler's), and
that is what has not been distilled: the cycle in `quantitative.core.native` is met under Scala
Native's `nscplugin` in the suspended-units run, and only in some builds (see
`doc/movestatics/repro/FIXME.md`).
