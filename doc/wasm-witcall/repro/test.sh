# Executable form of README.md, run by bin/proscala-test.

sjs_cp() { local l="$DIST/lib"; echo "$l/scala3-library_sjs1.jar:$(ls "$l"/scalajs-library_2.13-*.jar | head -1):$l/scalajs-scalalib_2.13.jar"; }

with_feature() {
  compiles -scalajs -cp "$(sjs_cp)" -d . Random.scala
  [ "$(strings 'Random$.sjsir' | grep -c -E '^(wasi:random/random@0.2.0|get-random-bytes)$')" -ge 2 ] \
    || fail "Random\$.sjsir does not record the WIT import"
  fails_with 'module name passed to witImportCall must be a String literal' -scalajs -cp "$(sjs_cp)" -d . NonConstant.scala
}

without_feature() {
  compiles -scalajs -cp "$(sjs_cp)" -d . NonConstant.scala
}
