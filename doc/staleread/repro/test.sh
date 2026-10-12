# Executable form of README.md, run by bin/proscala-test.
# src/ is a reduction of Soundness's gossamer.core at Soundness commit 211be67b5,
# and compiles only against that module's compile classpath *at that commit*
# (it no longer compiles against current Soundness, whose APIs have moved on).
# Supply it as $GOSSAMER_CORE_CP (`./mill show gossamer.core.compileClasspath` in
# a checkout of 211be67b5, built with a patched toolchain); without it the spec
# is skipped.
#
# The README's differential is trunk/3.9 against trunk-minus-staleread: the
# sources need the fork's other patches, so stock Scala cannot show the crash.

OPTS=(-experimental -new-syntax -preview -Xmax-inlines 32 -Yno-flexible-types -Yexplicit-nulls
  -language:experimental.modularity -language:experimental.dependent
  -language:experimental.relaxedLambdaSyntax -language:experimental.genericNumberLiterals
  -language:experimental.into -language:experimental.erasedDefinitions -language:implicitConversions
  -language:experimental.saferExceptions -language:experimental.strictEqualityPatternMatching
  -language:experimental.subCases -language:experimental.multiSpreads
  -Yno-predef -Yimports:java.lang,scala,proscenium
  -Ycc-new -language:experimental.captureChecking)

with_feature() {
  [ -n "${GOSSAMER_CORE_CP:-}" ] || skip "set GOSSAMER_CORE_CP to gossamer.core's classpath at Soundness 211be67b5"
  compiles "${OPTS[@]}" -cp "$GOSSAMER_CORE_CP" -d . src/*.scala
}

without_feature() {
  [ -n "${GOSSAMER_CORE_CP:-}" ] || skip "set GOSSAMER_CORE_CP to gossamer.core's classpath at Soundness 211be67b5"
  fails_with 'denotation .* invalid in run [0-9]+' "${OPTS[@]}" -cp "$GOSSAMER_CORE_CP" -d . src/*.scala
}
