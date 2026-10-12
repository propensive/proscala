# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -experimental -Ycc-new -language:experimental.separationChecking -d . mixed.scala
}

# Without this patch the compile crashes with the README's assertion. Stock
# Scala crashes earlier, on the same file, with an IllegalCaptureRef that another
# always-on Proscala patch fixes, so it never reaches this patch's site; either
# crash is upstream's behaviour here. (Recompiling the 3.9 tree with only this
# patch's hunk reverted gives exactly the README's assertion.)
without_feature() {
  fails_with 'assertion failed: attempting to add any to \{any\} of value x\$proxy1|IllegalCaptureRef' -experimental -Ycc-new -language:experimental.separationChecking -d . mixed.scala
}
