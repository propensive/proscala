# Reproduction

A macro whose quote pattern matches a string literal must keep matching the
literal its caller wrote. Without the `Mode.isQuotedPattern` gate, the
literal in the *pattern* is itself re-typed through the `Literate` instance
in scope, so the pattern silently stops matching and the macro takes a
different branch.

Compile in three steps — the macro must be a separate compilation unit from
its use, and the use site is deliberately compiled without the instance:

    scalac -experimental -d out text.scala
    scalac -experimental -cp out -d out macro.scala
    scalac -experimental -cp out -d out use.scala
    scala -cp out repro.use.run

Expected (patched): prints

    matched-empty-literal-case

Unpatched (or with the quote-pattern gate removed): prints

    fell-through-to-generic

which is the defect — no error is reported, the macro simply takes the
wrong branch. In Soundness this made `telekinesis`'s HTTP response macro
fail on every named-argument call with "the header “” cannot take a value of
type Http.Status", because its case for a positional argument — spelled
`'{("", $status: Http.Status)}` — had stopped matching.
