# Executable form of README.md, run by bin/proscala-test.

F="-experimental -language:experimental.inlineTraits"

with_feature() {
  mkdir -p a
  compiles $F -d a counter.scala
  runs '^2$' a app.Main
}

without_feature() {
  mkdir -p a
  reports 'MatchError: ImportType\(Ident\(Ordinals\)\)' $F -d a counter.scala
}
