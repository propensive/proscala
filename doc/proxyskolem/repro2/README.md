# Reproduction: proxyskolem (macro resplice)

The first of two reproductions (see also [`repro2/`](../repro2/README.md)):
a transparent inline macro respliceing an already-inlined dependent argument
mints a second, never-unifiable skolem.

Compile in **two runs** — the macro library first, then the use site against
it — with no special flags:

```
scalac -d out minilib.scala
scalac -classpath out -d out miniuse.scala
```

Without the patch, on a compiler carrying upstream #26563 (3.9.0-RC5 and
later), the second run fails with a type mismatch between two skolems minted
for the same argument — one by the original inlining of `s.get`, one by the
retype of the macro's resplice:

```
Found:    (?1 : ...)
Required: (?2 : ...)
```

With the patch, both runs succeed.

Derived by reduction from Soundness's `exoskeleton.Argument` (and the
matching failures in embarcadero and `caduceus.resend`).
