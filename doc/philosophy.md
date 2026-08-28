# The philosophy of Proscala

Proscala is not a new language. It is Scala, built from the upstream compiler
sources with a bounded, published set of patches — each one recorded in
[features/3.9](../features/3.9) and [features/3.10](../features/3.10),
documented under [doc/](README.md), and reproducible on its own. Full support
for the existing language is an invariant, not a goal: every change carried
here must leave every existing Scala program compiling, with unchanged
meaning. A patch that cannot honour that invariant does not belong in
Proscala.

Every patch falls into one of four categories, and the categories are the
policy: they describe not only what the fork contains today but what it is
allowed to contain tomorrow. The compatibility consequences of each — for
source, bytecode, and TASTy — are assessed in
[compatibility.md](compatibility.md).

## Bug fixes

The largest category by far — 34 of the 43 current patches — and
overwhelmingly concentrated in capture checking, where Proscala is exercised
against a large capture-checked codebase daily and upstream's experimental
implementation is still settling. A bug fix changes nothing about what the
language *is*; it makes the compiler do what its specification and evident
intent already say. Each fix is intended to be upstreamable, and each carries
a minimal reproduction so that the divergence can be retired the moment
upstream addresses it. The category also absorbs the fork's two backports
([depset](depset/depset.md), a performance fix upstream has already merged,
and [virtualdir](virtualdir/virtualdir.md), an API from the 3.10 line brought
to 3.9): backports are convergence with upstream, not deviation from it.

## Diagnostics

Better error reporting and richer debugging metadata never change what
compiles. [searchdiag](searchdiag/searchdiag.md) lets a
library author speak in the compiler's error messages;
[semdiag](semdiag/semdiag.md) makes diagnostics machine-readable with their
types intact; [smap](smap/smap.md) maps inlined code back to the source that
defined it, so debuggers and stack traces tell the truth about heavily inline
code. These are pure additions to the compiler's output channels: a program
observes no difference in its own behaviour.

## Platforms

The language unchanged, reaching more targets. [wasm](wasm/wasm.md) and
[wasm-witcall](wasm-witcall/wasm-witcall.md) teach the Scala.js backend to
emit WebAssembly components with typed WIT interfaces. Platform work
necessarily lives in the backend and touches no typing rule; it widens where
Scala programs can run without widening what a Scala program can mean.

## Eliminating special cases

Scala's specification hard-codes knowledge of particular library types into
general language constructs: splicing into a vararg position works only for
`Seq` and `Array`, string literals are only `java.lang.String`, numeric
literals are (primarily) the JVM primitives. The fourth category eliminates
such special cases, replacing each closed rule with an open protocol in which
the formerly privileged types become ordinary — and default — instances.

[spreadable](spreadable/spreadable.md) is the model. With it, `f(xs*)` no
longer asks "is this a `Seq` or an `Array`?" but "does this type have a
`scala.Spreadable` instance?" — and `Seq` and `Array` simply have one.
Nothing is added to the language surface; a closed rule becomes an open one,
and library types (safer collection abstractions, a dedicated text type, new
number types) get to participate in constructs that were previously reserved
for the standard library's choices.

This is not a departure from Scala's character but a continuation of it. The
language's own history moves in exactly this direction: `for` comprehensions
desugar to ordinary method calls on any type that provides them, string
interpolation is user-definable, pattern matching is an `unapply` call,
numeric literals already generalize through `FromDigits`. Eliminating a
special case removes compiler knowledge of specific types rather than adding
constructs — the language becomes more uniform, not larger.

The admission rule for this category is strict conservativity: a change
qualifies only if the old behaviour falls out as the default case of the new,
general rule. Existing code compiles unchanged with unchanged meaning,
because the types the compiler used to privilege remain instances of the
protocol that replaces the privilege.

## What is not accepted

Anything else. In particular: changes that alter the meaning of existing
programs, additions to surface syntax, and divergence from the language
specification other than the elimination of a special case under the rule
above. Where a
problem is best fixed in user code, Proscala declines to patch the compiler
even when a patch would be expedient — [localroots](localroots/localroots.md)
documents an upstream behaviour the fork deliberately does not touch, because
every affected call site was better fixed at source. The measure of the fork
is not how much it changes, but how little it needs to.
