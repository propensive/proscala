# Executable form of README.md, run by bin/proscala-test.

F="-experimental -language:experimental.captureChecking"

setup() {
  mkdir -p a b
  compiles $F -d a Box.scala
}

with_feature() {
  setup
  runs '^cached$' a app.Show
  compiles -experimental -from-tasty -d b -classpath a a/app/Box.tasty a/app/Show.tasty
  runs '^cached$' b app.Show
}

without_feature() {
  setup
  # Stock Scala uncaches the alias from source too: what it shows is only that the
  # recompilation does not keep a cached alias, as the fork without the patch did not.
  compiles -experimental -from-tasty -d b -classpath a a/app/Box.tasty a/app/Show.tasty
  runs '^uncached$' b app.Show
}
