# Executable form of README.md, run by bin/proscala-test.

F="-experimental -Ycc-new -language:experimental.captureChecking -language:experimental.separationChecking"

setup() {
  mkdir -p a b c d
  compiles $F -d a Loop.scala
}

with_feature() {
  setup
  compiles $F -from-tasty -d b -classpath a a/app/State.tasty a/app/Sorting.tasty
  compiles $F -Yskip:cc -from-tasty -d c -classpath a a/app/State.tasty
  compiles $F -Yskip:cc -d d Loop.scala
}

without_feature() {
  setup
  fails_with 'object State needs to extend Capability' $F -from-tasty -d b -classpath a a/app/State.tasty a/app/Sorting.tasty
  reports 'NoPhase\$ cannot be cast to class dotty.tools.dotc.cc.CheckCaptures' $F -Yskip:cc -from-tasty -d c -classpath a a/app/State.tasty
}
