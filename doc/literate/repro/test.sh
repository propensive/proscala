# Executable form of README.md, run by bin/proscala-test.
#
# No without_feature: the defect shown is the patch's own quote-pattern gate
# being missing, which neither the flagless compiler nor stock Scala (which has
# no scala.Literate at all) can exhibit.
ZFLAG=-Zliterate-literals

with_feature() {
  mkdir -p out
  compiles $ZFLAG -experimental -d out text.scala
  compiles $ZFLAG -experimental -cp out -d out macro.scala
  compiles $ZFLAG -experimental -cp out -d out use.scala
  runs '^matched-empty-literal-case$' out repro.use.run
}
