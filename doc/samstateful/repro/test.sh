# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -scalajs -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  # README expects a MutAdaptFailure here, but neither stock 3.9.0 nor the 3.9
  # tree with this patch's CaptureSet.scala hunk reverted reports one (checked
  # 2026-10-12, with and without -Ycc-new / separationChecking): the
  # reproduction no longer reproduces.
  skip "stale reproduction: the unpatched compiler accepts repro.scala"
}
