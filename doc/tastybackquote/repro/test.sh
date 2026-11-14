# Executable form of README.md, run by bin/proscala-test.

setup() {
  mkdir -p a b
  compiles -d a use.scala
  runs '^-1 -1$' a app.Use
  compiles -from-tasty -d b -classpath a a/app/Use.tasty
}

with_feature() {
  setup
  runs '^-1 -1$' b app.Use
}

without_feature() {
  setup
  runs '^5 1$' b app.Use     # both patterns match a value they should reject
}
