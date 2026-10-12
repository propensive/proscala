# Executable form of README.md, run by bin/proscala-test.

has_identity_set() {
  local IFS=: j
  for j in $COMPILER_CP; do
    case "$j" in
      *scala3-compiler*)
        [ "$(unzip -l "$j" 2>/dev/null | grep -c 'dotty/tools/dotc/util/MutableIdentitySet.class')" -gt 0 ] && return 0 ;;
    esac
  done
  return 1
}

with_feature() {
  has_identity_set || fail "the compiler has no MutableIdentitySet"
  bash gen.sh 3000
  compiles -d . Many.scala
}

without_feature() {
  if has_identity_set; then fail "the compiler already has MutableIdentitySet"; fi
}
