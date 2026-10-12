# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zretains-skolems

with_feature() {
  compiles $ZFLAG -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  fails_with 'Illegal capture reference: \(\?1 : Any\)' \
    -language:experimental.captureChecking -d . repro.scala
}
