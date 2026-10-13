# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . Macro_1.scala
  compiles -cp . -d . Test_2.scala
  runs '' . repro.Test
}

without_feature() {
  compiles -d . Macro_1.scala
  fails_with 'Macro expansion has type .* which does not conform to the expected type' -cp . -d . Test_2.scala
}
