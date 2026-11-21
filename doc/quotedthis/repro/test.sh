# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  local variant
  for variant in Protected Public Plain; do
    mkdir -p $variant
    compiles -d $variant $variant.scala
    compiles -cp $variant -d $variant Use.scala
    runs '^2$' $variant Use
  done
}

without_feature() {
  mkdir -p Protected Public Plain
  # the accessor calls itself: the use site is only warned, and would not terminate
  compiles -d Protected Protected.scala
  reports 'Infinite recursive call' -cp Protected -d Protected Use.scala
  # the nested quote keeps the `this` of a class it does not contain
  fails_with 'unresolved symbols: anonymous class' -d Public Public.scala
  # the accessor is entered in the class but never defined
  compiles -d Plain Plain.scala
  fails_with 'undefined: this\.inline\$table' -cp Plain -d Plain Use.scala
}
