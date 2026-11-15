# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -scalajs -d . repro.scala
  compiles -d . repro.scala
}

without_feature() {
  # Upstream's compiler is fetched without a Scala.js library to compile against;
  # ../repro shows the same fault on the JVM.
  [ -z "${STOCK_CP:-}" ] || skip "needs a Scala.js library, which --stock does not fetch"
  fails_with 'error overriding method text in trait Inspectable' -scalajs -d . repro.scala
  compiles -d . repro.scala
}
