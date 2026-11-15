# Executable form of README.md, run by bin/proscala-test.

setup() {
  mkdir -p a b c d
  compiles -d a e3.scala
}

with_feature() {
  setup
  compiles -from-tasty -d b -classpath a 'a/e3$package.tasty' a/e3.tasty a/Color.tasty
  runs '^Green$' b e3
  compiles -d c Lookup.scala Color.scala
}

without_feature() {
  setup
  fails_with 'wrong number of arguments .* expected: 2, found: 0' -from-tasty -d b -classpath a 'a/e3$package.tasty' a/e3.tasty a/Color.tasty
  compiles -from-tasty -d d -classpath a a/Color.tasty 'a/e3$package.tasty' a/e3.tasty
  fails_with 'not enough arguments for constructor Enum' -d c Lookup.scala Color.scala
}
