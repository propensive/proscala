# Capture-check inline argument proxies within their parameters' bounds

Stops capture checking from rejecting arguments of inline methods that capture what their parameters allow, by inferring each argument proxy's capture sets within the bounds its parameter declares.

Always on: it only turns programs that upstream rejects into accepted ones, and it accepts nothing a parameter's declared capture set forbids.

## Context

When an inline method is expanded, each argument that is not a simple path is
bound to a *proxy*, a local `val`, and the body refers to the proxy instead of the
parameter. The argument is then checked against the proxy's type alone.
[scala/scala3#26989](https://github.com/scala/scala3/pull/26989) (on `main`, and
backported to 3.10.0-RC3) gave proxies **explicit** types: the argument's type
from Typer. Before, they were inferred, which let an argument capture anything,
whatever its parameter declared
([scala/scala3#26982](https://github.com/scala/scala3/issues/26982), "inline
methods turn off capture checking"). That hole was real.

But Typer knows nothing about capture sets, so an argument's type from Typer,
taken at face value, says the argument captures nothing. Every argument that
captures anything was rejected — even where the same call compiles without
`inline` — and a capability type inside one (an array) was declared with a fresh
`any`, which separation checking then rejects too.

## Reproducing it

```scala
extension [value](iterable: Iterable[value])
  inline def fuse[state](base: state)(lambda: (state, value) ?=> state): state =
    val iterator: Iterator[value] = iterable.iterator
    var state: state = base
    while iterator.hasNext do state = lambda(using state, iterator.next())
    state

def fold[acc](initial: acc)(lambda: (Int, acc) => Exception => acc): acc =
  val errors = List[Exception]()
  (0 until errors.length).fuse(initial)(lambda(summon[Int], summon[acc])(errors(summon[Int])))
```

Scala 3.10.0 rejects it (`capability lambda cannot flow into capture set {}`),
although `fuse`'s `?=>` allows any capture, and without `inline` it compiles. So
does `inline def useOnly(io: Res)(x: Object^{io})` called with `identity(o)` for
an `o: Object^{io}`. In Soundness this failed a dozen modules.

## The solution

`Inliner.paramBindingDef` builds the proxy's type from two annotations Setup
already understands (and upstream uses for inline calls' type arguments): a part
annotated `@caps.internal.inferred` gets fresh capture-set variables, as an
inferred type, and inside one a part annotated `@caps.internal.declared` is
explicit again. The parameter types it bounds by are computed with the call's
inferred type arguments marked inferred (an inferred capture-set argument bounds
nothing).

**Any argument but a closure** is inferred, intersected with a declared bound on
its top-level capture set: the parameter's explicit set (`^{io}`, `^{}`), or
empty for a parameter of a pure type. A parameter that may capture anything — `^`,
a capability class, an array, an inferred type argument, a union with one — bounds
nothing. So `useOnly(io)(identity(o))` is accepted for `o: Object^{io}` and
rejected for an `o: Object^{other}`, and `usePure(identity(o))` is rejected for a
parameter `Object^{}`. Nested capture sets are inferred, as before #26989.

**A closure** keeps declared parameter and result types, so a leak through its
result is still caught, as in upstream's `cc-inline1`; its own capture set
follows the parameter's function type:

| parameter | the closure proxy's own capture set |
| --------- | ----------------------------------- |
| `A => B`, `A ?=> B` | inferred: exactly what the closure captures |
| `A ->{x} B` | `{x}`, as declared |
| `A -> B` | empty, as declared |

The same applies to a function in the closure's result. Its parameters are
declared as the parameter's function type declares them where that says something
about captures (`FileHandle^`, which is what catches `useFile(l => l)`), and
inferred where it says nothing, rather than declared from a capture-free Typer
type that would give an array a root of its own.

The patch's tests, `pos-custom-args/captures/proxycap.scala` (separation-checked)
and `neg-custom-args/captures/proxycap.scala`, cover each case in both
directions. Every error in upstream's `cc-inline1` is still reported, and the
outcome of every other test in `tests/{neg,pos}-custom-args/captures` is
unchanged.
