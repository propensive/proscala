# Reproduction: ctxresult

Compile `repro.scala` with:

```
scalac -language:experimental.captureChecking repro.scala
```

Without the patch, compilation fails with a level error of the form:

```
Reference `contextual$1` is not included in the allowed capture set {any}
of an enclosing function literal ...
where: any is a root capability in the result type of method foo9a
```

With the patch, the file compiles. The snippet is extracted verbatim from
[the feature doc](../ctxresult.md); the full version is the branch test
`tests/pos-custom-args/captures/erased-methods2.scala` (moved from `neg` to
`pos` by the patch).
