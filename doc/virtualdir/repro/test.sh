# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -cp "$COMPILER_CP" -d . UseVirtualDir.scala
  runs 'name=scratch empty=true' . useVirtualDir
}

without_feature() {
  fails_with 'virtualDirectory is not a member of' -cp "$COMPILER_CP" -d . UseVirtualDir.scala
}
