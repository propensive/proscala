# Executable form of README.md, run by bin/proscala-test.
#
# No without_feature: this shape does not crash stock 3.10.0 (checked
# 2026-10-12), so it cannot yet demonstrate the bug. See README.md.

with_feature() {
  compiles -d . Internal.scala Amount.scala
}
