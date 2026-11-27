# Executable form of README.md, run by bin/proscala-test.

OPTIONS="-language:experimental.captureChecking -language:experimental.separationChecking"

with_feature() {
  compiles $OPTIONS -d . macro.scala
  compiles $OPTIONS -cp . -d . client.scala
}

without_feature() {
  # Upstream has no `anonascribe`, so the ascription is not treated as inferred there
  # and has no capture set variables to share: the failure is one of the fork's own.
  skip "the failure arises from the anonascribe patch, which upstream does not have"
}
