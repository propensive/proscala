# Executable form of README.md, run by bin/proscala-test.

setup() {
  mkdir -p l a b c
  compiles -d l lib.scala alias.scala
  compiles -d a -cp l use.scala
}

with_feature() {
  setup
  # a unit recompiled from its TASTy
  compiles -from-tasty -d b -cp l:a a/use/Direct.tasty a/use/Inferred.tasty a/use/Aliased.tasty
  # an ordinary compilation against a separately compiled `val ref: Cell[String]`,
  # run against the classes recompiled from TASTy
  compiles -d c -cp l:a client.scala
  runs '^a a b$' c:b:l client.Client
}

without_feature() {
  setup
  compiles -from-tasty -d b -cp l:a a/use/Direct.tasty a/use/Inferred.tasty
  fails_with 'expression does not take parameters' -from-tasty -d b -cp l:a a/use/Aliased.tasty
  fails_with 'expression does not take parameters' -d c -cp l:a client.scala
}
