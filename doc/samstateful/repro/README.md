# Reproduction: samstateful

Compile `repro.scala` **to Scala.js** with capture checking (on the JVM the
SAM literal stays a closure and the bug does not fire):

```
scalac -scalajs -language:experimental.captureChecking repro.scala
```

Without the patch, the SAM literal is expanded to an anonymous class before
capture checking, and adapting the inherited constant `{ResultCap}` capture
set to read-only fails with a mutability-adaptation (`MutAdaptFailure`) error.

With the patch, the file compiles. The snippet is extracted verbatim from
[the feature doc](../samstateful.md).
