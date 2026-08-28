# Compatibility

What using Proscala means for your source code and your published artifacts.
This document answers the four questions anyone weighing an adoption asks,
then groups every change the fork carries by the answers. The categories of
*acceptable* change are described in [philosophy.md](philosophy.md); this is
the companion assessment of their consequences.

The four questions:

1. **Does existing Scala source compile under Proscala, unchanged in
   meaning?** Yes — this is the fork's invariant — with two deliberate,
   narrow exceptions described under "Where the compilers disagree" below,
   both of which reject only code exploiting an upstream soundness leak.
2. **Does source written against Proscala compile under vanilla Scala?**
   That depends on which features it uses; each category below says.
3. **For source both compilers accept, are the artifacts identical?** By
   default, yes, byte for byte. The exceptions are enumerated exhaustively
   below, and all are confined to runs using experimental capture checking
   or an opt-in flag.
4. **Can vanilla toolchains consume Proscala-produced artifacts?** The fork
   does not change any format: classfiles are conformant JVM classfiles and
   TASTy uses upstream's version number unmodified (the compiler identifies
   itself with a `-propensive` version suffix). Consumability turns on one
   thing only: whether an artifact *refers to* a library type that exists
   only in Proscala's standard library.

Everything Proscala adds is opt-in — behind a compiler flag, an annotation,
an `@experimental` library type, or an experimental language feature.
Compiling an existing codebase with Proscala and none of these enabled
produces artifacts indistinguishable from vanilla output.

## Diagnostics only

[semdiag](semdiag/semdiag.md) (`-Xsemantic-diagnostics`) changes what the
compiler *prints*, never what it produces: without the flag, output is
byte-for-byte unchanged; with it, only the console stream differs.
[searchdiag](searchdiag/searchdiag.md) changes which *message* an already-
failing implicit search reports — search outcomes, and therefore emitted
code and TASTy, are unchanged. Neither affects any of the four questions
for code that compiles.

The one footnote is searchdiag's annotation: `@scala.annotation.internal.diagnostic`
is a Proscala library class, so a source file naming it does not compile
under vanilla Scala, and the annotated given's own TASTy mentions the
class. This costs downstream users nothing: the annotation is compile-time
only (never loaded at runtime, no classfile attribute), and a vanilla
consumer of such a library simply gets the ordinary "no given instance"
message where a Proscala consumer gets the custom one.

## Debug metadata

[smap](smap/smap.md) (`-Xjsr45`, off by default) is the only feature that
changes emitted JVM classfiles for code both compilers accept — and only
their metadata: it populates the standard `SourceDebugExtension` attribute
(JSR-45) and gives inlined code synthetic `LineNumberTable` entries past
the end of the primary source. Instruction streams and TASTy are unchanged.
The classfiles are fully conformant; the JVM ignores the attribute, and
JSR-45-aware debuggers resolve it. The one visible caveat: a raw stack
trace through inlined code shows the synthetic line numbers — remapping
them through the SMAP is the consumer's job.

## Accepting more programs

The bug fixes — the large majority of the fork — move programs from
"crash, hang, or spurious error" to "compiles". For code vanilla Scala
already compiled, they change nothing; code that *needs* them will not
compile under a vanilla compiler until the fix is upstreamed, which is the
intended fate of every one of them. Their artifacts are ordinary in format.

Two gradations matter:

- Around two dozen of the fixes fire only under
  `-language:experimental.captureChecking` (some further gated on
  `-Ycc-new` or separation checking). If you don't use capture checking,
  they are inert.
- The always-on fixes ([nullreceiver](nullreceiver/nullreceiver.md),
  [permitlazy](permitlazy/permitlazy.md), [anonspec](anonspec/anonspec.md),
  [macroalias](macroalias/macroalias.md), [modulepath](modulepath/modulepath.md),
  [prunecomplete](prunecomplete/prunecomplete.md),
  [integratemap](integratemap/integratemap.md),
  [staleread](staleread/staleread.md)) fire only where the unpatched
  compiler crashed or rejected outright, so they cannot change the output
  of previously-working code.

One consequence deserves spelling out for library authors using capture
checking: inferred capture sets are pickled into TASTy, so several cc fixes
([iarraypure](iarraypure/iarraypure.md), [unboxedpure](unboxedpure/unboxedpure.md),
[aliascap](aliascap/aliascap.md), [unioncaps](unioncaps/unioncaps.md),
[iarraypure-mutalias](iarraypure-mutalias/iarraypure-mutalias.md)) change
*which* capture annotations a cc-compiled artifact carries — corrected ones
rather than the spurious ones vanilla infers. The format is identical, and
capture checking is experimental on both compilers, so such artifacts were
already outside vanilla's stability guarantees; Proscala changes their
content for the better, not their nature.

## New library types

[spreadable](spreadable/spreadable.md) adds `scala.Spreadable`
(`@experimental`) to the standard library. At a splice site the feature
either casts (when the instance's representation is already the underlying
`Seq`/`Array` — zero cost, bytecode identical to a hand-written boundary
cast) or calls the instance's `spread` method. Both forms are ordinary
bytecode running on an ordinary JVM. The dependency is the library:
defining or using a `Spreadable` instance puts `scala.Spreadable` in your
TASTy (and, for the instance, your classfiles), so compiling against such
an artifact — including expanding an inline method containing a backed
splice — and running it require Proscala's `scala3-library` on the
classpath. Source using the feature does not compile under vanilla Scala.

## New platforms

[wasm](wasm/wasm.md) and [wasm-witcall](wasm-witcall/wasm-witcall.md)
target the WebAssembly Component Model through the Scala.js toolchain.
These are best understood as a new target rather than a change to an
existing one: JVM artifacts are never involved, and Scala.js code free of
WIT annotations is compiled exactly as before. Code that does use
`scala.scalajs.wit.*` needs the whole vendored toolchain — the
WIT-extended Scala.js IR and the scala-wasm runtime — and its `.sjsir` is
not consumable by a stock Scala.js linker. Since the output is a WASM
component, "consumable by vanilla Scala" is not the relevant question;
conformance to the Component Model is.

## Where the compilers disagree

The honest list: every known case where Proscala's behaviour differs for
code a vanilla compiler accepts.

- **[givenprefix](givenprefix/givenprefix.md)** (always on) rejects code
  that reads an opaque type's representation through an extension method
  from a top-level given — a leak of the package object's privileged view
  that upstream already fixed for direct selections (the #18097 family)
  but not for implicit search. Code affected was depending on the leak;
  the fix is a candidate for upstreaming. This is the main case where
  question 1's "yes" needs the qualifier.
- **[iarraypure-mutalias](iarraypure-mutalias/iarraypure-mutalias.md)**
  (capture checking with `-Ycc-new` only) rejects mutation through an
  opaque alias over a mutable type — closing a soundness hole. Code that
  treats such an alias as immutable-by-convention must accept read-only
  tracking or change representation.
- **[givencache](givencache/givencache.md)**: when capture checking is
  enabled anywhere in a run, the `UncacheGivenAliases` optimization is
  skipped run-wide, so a given alias remains a `lazy val` (field plus
  accessor) where vanilla demotes it to a `def` — different bytecode and a
  different pickled member for code that compiles under both. Semantics
  are unchanged on the JVM; the feature doc records one Scala.js linker
  interaction (a field initialized before the super constructor call).
  [splicealias](splicealias/splicealias.md) is run-scoped the same way for
  quote type binders. Neither affects runs that never enable cc.
- **[proxyskolem](proxyskolem/proxyskolem.md)** (cc units only) keeps the
  pre-3.9.0-RC5 widened type for inline argument proxies, deliberately
  giving up upstream's more precise dependent-inline results under capture
  checking until the interaction is fixed properly.
- **[modulepath](modulepath/modulepath.md)** gives a module's inline
  accessor a `TermRef` result where vanilla 3.10 pickles a `TypeRef`; the
  two erase identically, so classfiles agree and only the pickled
  signature differs (matching what vanilla 3.9 pickles).

## Practical guidance

**Publishing a library.** If your artifact's API and TASTy mention no
Proscala-only library type and you don't compile with capture checking,
your output is indistinguishable from vanilla output: consumers on vanilla
Scala notice nothing, and you can switch compilers in either direction at
any release. Using `Spreadable` (or the searchdiag annotation on a public
given) makes Proscala's library a compile-time dependency of your
consumers; `Spreadable` instances make it a runtime one.

**Mixing compilers in one build.** Safe wherever the boundary artifacts
satisfy the rule above. The compilers agree on TASTy version, so neither
rejects the other's files on version grounds.

**Runtime.** Nothing in the fork requires a special JVM. The only runtime
requirement any feature introduces is `scala.Spreadable` on the classpath
where instances are loaded, and the scala-wasm runtime for the WASM target.

**Debugging.** With `-Xjsr45`, prefer a JSR-45-aware debugger; expect raw
stack traces through inlined code to show synthetic line numbers.
