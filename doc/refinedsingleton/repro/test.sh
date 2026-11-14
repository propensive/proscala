# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -experimental -d . repro.scala
}

without_feature() {
  fails_with 'Required: app.Reader\{type Topic = reader.Topic\}\^\{reader\}' -experimental -d . repro.scala
}
