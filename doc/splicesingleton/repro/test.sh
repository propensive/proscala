# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . Macro_1.scala
  compiles -cp . -d . Test_2.scala
  # the value is still checked against the type parameter's bound
  compiles -d . PureMacro_3.scala
  fails_with 'does not conform to upper bound Pure' -cp . -d . PureTest_4.scala
}

without_feature() {
  compiles -d . Macro_1.scala
  fails_with 'Required: \(path : Path\^\{io\}\)\^\{path\}' -cp . -d . Test_2.scala
}
