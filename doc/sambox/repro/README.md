# Reproduction: sambox

Compile `repro.scala` **to Scala.js** with capture checking (on the JVM the
lambda stays a closure and the bug does not fire):

```
scalac -scalajs -language:experimental.captureChecking repro.scala
```

Without the patch, `ExpandSAMs` turns the lambda into an anonymous class
before capture checking and compilation fails with a spurious
"type mismatch / does not conform" error on the synthetic
`type Self = Handle` member.

With the patch, the file compiles. The snippet is extracted verbatim from
[the feature doc](../sambox.md).
