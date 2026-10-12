# Executable form of README.md, run by bin/proscala-test.
# caps.SharedUnscoped is in the supplementary proscala-library, which the
# distribution's scalac has on its classpath.

with_feature() {
  fails_with 'because any in an enclosing function is not visible from any[^ ]* in value x\$proxy1' \
    -experimental -Ycc-new -language:experimental.separationChecking -d . ambient-shared-only.scala
  compiles -experimental -Ycc-new -language:experimental.separationChecking -d . ambient.scala
}

without_feature() {
  # Upstream has no caps.SharedUnscoped, so the only classification it offers
  # is SharedCapability — which fails as above — and ambient.scala does not resolve.
  fails_with 'because any in an enclosing function is not visible from any[^ ]* in value x\$proxy1' \
    -experimental -Ycc-new -language:experimental.separationChecking -d . ambient-shared-only.scala
  fails_with 'SharedUnscoped is not a member of (scala\.)?caps' \
    -experimental -Ycc-new -language:experimental.separationChecking -d . ambient.scala
}
