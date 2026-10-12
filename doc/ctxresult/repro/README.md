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

With the patch, the file compiles. The snippet is extracted from
[the feature doc](../ctxresult.md), except that `CT` also extends
`compiletime.Erased` (with `language.experimental.erasedDefinitions`), as in the
branch test: the context parameters are then erased, which keeps the curried
dependent context function type out of the "not yet supported" implementation
restriction that would otherwise reject the file for an unrelated reason; the full version is the branch test
`tests/pos-custom-args/captures/erased-methods2.scala` (moved from `neg` to
`pos` by the patch).
