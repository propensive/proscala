# Reproduction: macroalias

Compile in **two runs** — the macro library first, then the use site against
it — with no special flags:

```
scalac -d out m.scala
scalac -classpath out -d out u.scala
```

Without the patch, on the 3.10 stream (the macro-expansion conformance check
was introduced there by upstream #25756), the second run rejects both macro
calls in `u.scala`:

```
Macro expansion has type ... does not conform to the expected type ...
```

— the expected type (from `m.scala`'s TASTy) has its opaque `Timestamp`
revealed, while the actual type of the unpickled expansion still names the
ordinary alias `internal.Date` and is left unrevealed.

With the patch, both runs succeed.

Earlier streams compile the pair either way: they carry no such conformance
check. Derived by reduction from aviation's date literals (`2000-Jan-1`).
