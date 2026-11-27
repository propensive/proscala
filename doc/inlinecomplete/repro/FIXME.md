# FIXME: no self-contained reproduction yet

The failure is reproduced by compiling Soundness's `jacinta.core` (at
`toolchain/proscala-main`, 2026-11-27) with Proscala on scala/scala3 `main`
(`0ed42a2d89`): without the patch,

```
-- [E007] Type Mismatch Error: lib/jacinta/src/core/jacinta.Json.scala:650:28
    |            fields(value): [field] =>
    |                           ^
    |Found:    [field] -> (field: field) -> (...) ?=> jacinta.Json.Ast
    |Required: [field] -> field => (...) ?=> jacinta.Json.Ast^'s1
    |
    |Note that capability `contextual$57` cannot flow into capture set {}.
```

and with it the module compiles. The stack of the error (`-Ydebug-error`) shows
the route: `CheckCaptures.postCheck` traverses the unit, a member taken as seen
from a prefix asks for the info of a symbol inside the inline method
`EncodableDerivation.conjunction`, and its completer rechecks it
(`Setup` completer → `completeDef` → `recheckDef`), and with it the enclosing
closures, which `completeDef` completes on the way to building the environment.

Two attempts at a small file with the same shape — an inline method whose body
passes a polymorphic lambda capturing a context parameter to another inline
method, with a local `val` of inferred type beside it — compile unpatched on
stock 3.10.2-RC2: what makes the final pass ask for the symbol's info was not
isolated.
