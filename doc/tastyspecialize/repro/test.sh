# Executable form of README.md, run by bin/proscala-test.

F="-experimental -language:experimental.inlineTraits"

setup() {
  mkdir -p a b c
  compiles $F -d a counter.scala
  runs '^4$' a app.Main
}

with_feature() {
  setup
  # the unit declaring the trait, and with it the class extending it
  compiles $F -from-tasty -d b -classpath a a/app/Counting.tasty a/app/Counter.tasty a/app/Doubler.tasty a/app/Main.tasty
  runs '^4$' b app.Main
}

without_feature() {
  setup
  fails_with 'is declared as `inline`, but was not inlined' $F -from-tasty -d b -classpath a a/app/Counter.tasty
  # the class alone recompiles, to a constructor calling an initializer the trait lacks
  compiles $F -from-tasty -d c -classpath a a/app/Doubler.tasty
  mkdir -p d && cp -R a/. d/ && cp c/app/Doubler.class d/app/
  set +e; out="$(java -cp "d:$JAVA_CP" app.Main 2>&1)"; set -e
  printf '%s\n' "$out" | grep -q 'NoSuchMethodError' || fail "expected a NoSuchMethodError, got: $out"
}
