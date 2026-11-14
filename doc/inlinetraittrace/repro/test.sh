# Executable form of README.md, run by bin/proscala-test.

F="-experimental -language:experimental.inlineTraits"

setup() {
  mkdir -p l a b
  compiles $F -d l lib.scala
  compiles $F -d a -classpath l use.scala
}

with_feature() {
  setup
  compiles $F -from-tasty -d b -classpath a:l a/app/Parser.tasty
}

without_feature() {
  setup
  reports 'owner discrepancy for local value \$proxy1' $F -from-tasty -d b -classpath a:l a/app/Parser.tasty
}
