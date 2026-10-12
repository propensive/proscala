# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . crash.scala
}

without_feature() {
  # Upstream #26842 (in 3.10.0, and in this stream's base) removed the `.get`,
  # so no upstream compiler since 3.10.0-RC1 crashes on crash.scala.
  skip "the None.get crash was fixed upstream by #26842; stock no longer reproduces it"
}
