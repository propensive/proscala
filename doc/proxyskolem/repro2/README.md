# Reproduction: proxyskolem (macro resplice)

One of two reproductions (the other, the capture flow, is
[`repro/`](../repro/README.md)):
a transparent inline macro respliceing an already-inlined dependent argument
mints a second, never-unifiable skolem.

Compile in **two runs** — the macro library first, then the use site against
it — under capture checking:

```
scalac -language:experimental.captureChecking -d out minilib.scala
scalac -language:experimental.captureChecking -classpath out -d out miniuse.scala
```

Capture checking is needed for the *patch*, not for the bug: the patch keeps
the widened proxy type only in capture-checked units, so without the language
import the patched 3.9 compiler fails exactly as stock 3.9.0 does.

Without the patch, on a compiler carrying upstream #26563 (3.9.0-RC5 and
later), the second run fails with a type mismatch between two skolems minted
for the same argument — one by the original inlining of `s.get`, one by the
retype of the macro's resplice:

```
Found:    (?1 : ...)
Required: (?2 : ...)
```

With the patch, both runs succeed.

On the 3.10 line this mode does not reproduce: stock 3.10.0 compiles both runs
(with or without capture checking, checked 2026-10-12), and upstream #26872,
later on `main`, removed the skolem-typed proxy altogether. Only the 3.9 stream
shows the failure unpatched.

Derived by reduction from Soundness's `exoskeleton.Argument` (and the
matching failures in embarcadero and `caduceus.resend`).
