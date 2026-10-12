# Executable form of README.md, run by bin/proscala-test.

sjs_cp() { local l="$DIST/lib"; echo "$l/scala3-library_sjs1.jar:$(ls "$l"/scalajs-library_2.13-*.jar | head -1):$l/scalajs-scalalib_2.13.jar"; }
wit_import_in_ir() { [ "$(strings 'Host$.sjsir' | grep -c 'example:host/utils@0.1.0')" -gt 0 ]; }

with_feature() {
  compiles -scalajs -cp "$(sjs_cp)" -d . Component.scala
  wit_import_in_ir || fail "Host\$.sjsir records no WIT import"
  fails_with '@WitRecord class must be final' -scalajs -cp "$(sjs_cp)" -d . NotFinal.scala
}

without_feature() {
  compiles -scalajs -cp "$(sjs_cp)" -d . Component.scala
  if wit_import_in_ir; then fail "Host\$.sjsir records a WIT import"; fi
  compiles -scalajs -cp "$(sjs_cp)" -d . NotFinal.scala
}
