# Executable form of README.md, run by bin/proscala-test.

needs_jdk25() {
  local v
  v="$(java -XshowSettings:properties -version 2>&1 | sed -nE 's/^ *java\.specification\.version = ([0-9]+).*/\1/p')"
  [ "${v:-0}" -ge 25 ] || skip "needs JDK 25 (java.lang.classfile); running on JDK ${v:-unknown}"
}

with_feature() {
  needs_jdk25
  compiles -d . repro.scala
}

without_feature() {
  needs_jdk25
  fails_with 'Cyclic reference involving class BufferedMethodBuilder' -d . repro.scala
}
