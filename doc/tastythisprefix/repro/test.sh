# Executable form of README.md, run by bin/proscala-test.

setup() {
  mkdir -p a b
  compiles -d a Encoder.scala
}

with_feature() {
  setup
  compiles -from-tasty -d b -classpath a a/app/Encoder.tasty
}

without_feature() {
  setup
  fails_with 'value raster cannot be accessed as a member of \(Encoder_this' -from-tasty -d b -classpath a a/app/Encoder.tasty
}
