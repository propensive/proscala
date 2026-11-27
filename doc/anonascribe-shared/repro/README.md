# Reproduction: anonascribe-shared

Two files, compiled separately, with capture checking and separation checking:

```
scalac -language:experimental.captureChecking -language:experimental.separationChecking -d . macro.scala
scalac -language:experimental.captureChecking -language:experimental.separationChecking -cp . -d . client.scala
```

With `anonascribe` but without this patch, the second expansion of the macro in
`client.scala` is rejected:

```
-- [E007] Type Mismatch Error: client.scala:5:53 -------------------------------
5 |def second(payload: String)(using Tactic): Request = submit(payload)
  |                                                     ^^^^^^^^^^^^^^^
  |Note that capability `postable$proxy2` cannot flow into capture set {any}
  |because (postable$proxy2 : Postable^{x$2}) in method second is not visible from any in value request.
```

With the patch, both files compile.

The trigger is a macro whose quoted code instantiates an anonymous class which
captures something of the expansion, expanded at least twice in one compilation
unit, at different depths. With `first` removed, or with `submit` an ordinary
inline method without a quote, the file compiles unpatched.

Stock upstream compiles these files: without `anonascribe` the ascription gets
no capture set variables, so there are none to share.

Reduced from Soundness's obligatory, whose `JsonRpc.request` and
`JsonRpc.notification` each expand telekinesis's `submit`.
