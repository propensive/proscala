# Executable form of README.md, run by bin/proscala-test.
# repro.scala needs the classpath of Soundness's ethereal.test module, which this
# spec reads from a built Soundness checkout named by $SOUNDNESS (Mill's cached
# out/ethereal/test/compileClasspath.json; run `./mill ethereal.test.compile` there
# first). Without it, the spec is skipped.
ZFLAG=-Zretains-skolems

soundness_classpath() {
  local json="${SOUNDNESS:-}/out/ethereal/test/compileClasspath.json"
  [ -n "${SOUNDNESS:-}" ] || skip "set SOUNDNESS to a built Soundness checkout"
  [ -f "$json" ] || skip "$json not found: build ethereal.test in \$SOUNDNESS"
  CLASSPATH_ETHEREAL="$(python3 -I -c '
import json, re, sys
print(":".join(re.sub(r"^q?ref:v\d+:[0-9a-f]+:", "", e) for e in json.load(open(sys.argv[1]))["value"]))' "$json")"
}

# Soundness's standard options, less its compiler plugins, warnings and -Z flags
OPTS=(-experimental -new-syntax -preview -Xmax-inlines 32 -Yno-flexible-types -Yexplicit-nulls
  -language:experimental.modularity -language:experimental.dependent
  -language:experimental.relaxedLambdaSyntax -language:experimental.genericNumberLiterals
  -language:experimental.into -language:experimental.erasedDefinitions -language:implicitConversions
  -language:experimental.saferExceptions -language:experimental.strictEqualityPatternMatching
  -language:experimental.subCases -language:experimental.multiSpreads
  -Yno-predef -Yimports:java.lang,proscenium
  -Ycc-new -language:experimental.captureChecking -language:experimental.separationChecking)

with_feature() {
  soundness_classpath
  compiles $ZFLAG "${OPTS[@]}" -cp "$CLASSPATH_ETHEREAL" -d . repro.scala
}

without_feature() {
  soundness_classpath
  fails_with 'Illegal capture reference: \(\?1 : Any\)' "${OPTS[@]}" -cp "$CLASSPATH_ETHEREAL" -d . repro.scala
}
