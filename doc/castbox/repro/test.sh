# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  fails_with 'Required: +internal\.Tagged\[(box )?\(inst : Object\^\{t\}\)' -language:experimental.captureChecking -d . repro.scala
}
