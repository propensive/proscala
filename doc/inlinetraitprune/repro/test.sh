# Executable form of README.md, run by bin/proscala-test.

F="-experimental -language:experimental.inlineTraits"

with_feature() {
  mkdir -p a b
  compiles $F -d a reader.scala counter.scala
  compiles $F -d b counter.scala reader.scala
}

without_feature() {
  mkdir -p a b
  fails_with 'Concrete method has no definition: def advance\(\): Unit' $F -d a reader.scala counter.scala
  compiles $F -d b counter.scala reader.scala
}
