# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zinline-source-maps

smap() { javap -v Main.class 2>/dev/null; }

with_feature() {
  compiles $ZFLAG -d . Util.scala Main.scala
  [ "$(smap | grep -c 'SourceDebugExtension')" -gt 0 ] || fail "Main.class has no SourceDebugExtension"
  [ "$(smap | grep -c 'Util.scala')" -gt 0 ] || fail "Main.class's SMAP does not name Util.scala"
}

without_feature() {
  compiles -d . Util.scala Main.scala
  if smap | grep -q 'SourceDebugExtension'; then fail "Main.class has a SourceDebugExtension without the flag"; fi
}
