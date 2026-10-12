# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  mkdir -p out
  compiles -d out m.scala
  compiles -classpath out -d out u.scala
}

without_feature() {
  mkdir -p out
  compiles -d out m.scala
  fails_with 'Macro expansion has type repro\.internal\.Date, which does not conform to the expected type' -classpath out -d out u.scala
}
