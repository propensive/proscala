# Executable form of README.md, run by bin/proscala-test.

setup() {
  mkdir -p a b
  compiles -d a Trace.scala
  runs '^app\.Trace\$\.main\(Trace\.scala:4\)$' a app.Trace
  compiles -from-tasty -d b -classpath a a/app/Trace.tasty
}

with_feature() {
  setup
  runs '^app\.Trace\$\.main\(Trace\.scala:4\)$' b app.Trace
}

without_feature() {
  setup
  runs '^app\.Trace\$\.main\(Trace\.tasty:1\)$' b app.Trace
}
