# Executable form of README.md, run by bin/proscala-test.
# Always on: no -Z flag.

# -release 17 reads ct.sym only when the running JDK is newer than 17; on an
# older one the real jdk.internal.ValueBased is found and nothing is synthesized.
jdk="$(java -XshowSettings:properties -version 2>&1 | awk -F' = ' '/java.specification.version/ {print $2}')"
[ "${jdk:-0}" -gt 17 ] || skip "needs a JDK newer than 17 so that -release 17 reads ct.sym (have ${jdk:-unknown})"

with_feature() {
  compiles -release 17 -d . Macro.scala Use.scala
}

without_feature() {
  fails_with 'StaleSymbolException: stale symbol; trait ValueBased' -release 17 -d . Macro.scala Use.scala
}
