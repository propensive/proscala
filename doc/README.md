# Feature documentation

The categories these features fall into, and the policy governing what
Proscala accepts, are described in [philosophy.md](philosophy.md); the
consequences of each for source and artifact compatibility are assessed in
[compatibility.md](compatibility.md).

One subdirectory per feature. Each `doc/<feature>/` contains the feature's
documentation (`<feature>.md`) and, for bug fixes, a `repro/` directory with a
minimal reproduction — either standalone source files with a `README.md`
giving the compiler flags and expected failure, or a `FIXME.md` where no
self-contained reproduction is known yet. The same documentation applies to
every stream that carries the feature; where streams genuinely differ, the
directory carries a clearly named variant file (none at present).

The `Streams` column is the human-readable view of the per-stream patch lists in
`features/<stream>` on this branch; the two must agree. The build is **not** a
patch — it lives on `main` and is overlaid onto a code branch at build time, so it
has no `feature/<stream>/make` branch and no row below — but it is documented
alongside the features, in [make/make.md](make/make.md). [boundscap](boundscap/boundscap.md)
likewise has no row: it applied only to the 3.8 stream, retired in August 2026, and
its analysis and reproduction are kept as a record.
[picklesource](picklesource/picklesource.md) is retired too: it applied only to
the 3.10 stream, and upstream #26900 (in the base since August 2026) fixes the
same assertion at its source.
[localroots](localroots/localroots.md) also has no row: it documents an upstream
3.10 capture-checking behaviour (memoized local roots failing the second inline
expansion in a unit) that the fork deliberately does **not** patch — every
affected Soundness site was fixed honestly at source — kept with its two
reproductions so the diagnostic is recognisable when it next appears.

| Feature | Description | Streams | Kind | Repro |
| ------- | ----------- | ------- | ---- | ----- |
| [aliascap](aliascap/aliascap.md) | Keep root capabilities global in type alias infos | 3.9, 3.10 | bug fix | yes |
| [anonspec](anonspec/anonspec.md) | Treat non-specialized anonymous-class parents as such, not as a crash | 3.10 | bug fix (crash) | yes |
| [anykindcap](anykindcap/anykindcap.md) | Do not constrain type arguments by an `AnyKind` bound's capture set | 3.10 | bug fix | yes |
| [blockimport](blockimport/blockimport.md) | Recheck a block's result expression in its statements' context | 3.9, 3.10 | bug fix | yes |
| [boolunapply](boolunapply/boolunapply.md) | Keep Boolean results of nullary case-class unapplies under capture checking | 3.10 | bug fix | yes |
| [castbox](castbox/castbox.md) | Box opaque-external type arguments in cast type applications | 3.9 | bug fix | yes |
| [ctxresult](ctxresult/ctxresult.md) | Context-result closures level-checked at the method's level | 3.9, 3.10 | bug fix | yes |
| [dependarg](dependarg/dependarg.md) | Conserve stable argument paths in dependent-application rechecking | 3.9, 3.10 | bug fix | yes |
| [depset](depset/depset.md) | Add a mutable IdentitySet to optimize variable dependencies in CC | 3.9 | backport (perf) | n/a |
| [dictcaps](dictcaps/dictcaps.md) | Infer the capture set of recursive-implicit dictionary instances | 3.9, 3.10 | bug fix | yes |
| [givencache](givencache/givencache.md) | Keep given aliases cached when capture checking is enabled | 3.9, 3.10 | bug fix (crash) | yes |
| [givenprefix](givenprefix/givenprefix.md) | Seal package-object prefixes on implicit candidate references | 3.9, 3.10 | bug fix | yes |
| [iarraypure](iarraypure/iarraypure.md) | Treat `IArray` as pure under capture checking | 3.9, 3.10 | bug fix | yes |
| [iarraypure-mutalias](iarraypure-mutalias/iarraypure-mutalias.md) | Classify opaque aliases over mutable types under capture checking | 3.9, 3.10 | bug fix | yes |
| [inertcache](inertcache/inertcache.md) | Cache inert types in capture-checking Setup | 3.9, 3.10 | bug fix (hang) | yes |
| [inlineupdate](inlineupdate/inlineupdate.md) | Propagate update classification to inline accessors | 3.9, 3.10 | bug fix | yes |
| [integratemap](integratemap/integratemap.md) | Evaluate IntegrateMap symbols in the spliced run context | 3.10 | bug fix (crash) | yes |
| [lazycycle](lazycycle/lazycycle.md) | Guard against cyclic LazyRef graphs in capture-checking Setup | 3.9, 3.10 | bug fix (crash) | FIXME (not triggered by current Soundness) |
| [literate](literate/literate.md) | Re-type literals through a `Literate` instance in scope | 3.9, 3.10 | feature | yes |
| [macroalias](macroalias/macroalias.md) | Strip ordinary aliases when the macro-expansion check reveals opaques | 3.10 | bug fix | yes |
| [modulepath](modulepath/modulepath.md) | Give an inline accessor for a module the module's `TermRef` | 3.10 | bug fix | yes |
| [nullreceiver](nullreceiver/nullreceiver.md) | Widen bottom-typed call receivers to Object in the backend | 3.9, 3.10 | bug fix (crash) | yes |
| [permitlazy](permitlazy/permitlazy.md) | Lazy resolution of permitted subclasses in classfile parsing | 3.9, 3.10 | bug fix | yes |
| [proxyskolem](proxyskolem/proxyskolem.md) | No skolem-typed inline argument proxies under capture checking | 3.9, 3.10 | bug fix | yes (2: `repro`, `repro2`) |
| [prunecomplete](prunecomplete/prunecomplete.md) | Do not force completion when filtering prunable inline methods | 3.10 | bug fix (crash) | FIXME |
| [retainbounds](retainbounds/retainbounds.md) | Sanitize `TypeBounds` in `@retains` arguments to the top capability | 3.9, 3.10 | bug fix | yes |
| [returnavoid](returnavoid/returnavoid.md) | Avoid only pattern-bound term symbols in rechecked returns | 3.9, 3.10 | bug fix | yes |
| [sambox](sambox/sambox.md) | Capability-implied captures on SAM anonymous-class type members | 3.9, 3.10 | bug fix | yes |
| [samstateful](samstateful/samstateful.md) | Read-only views of constant method-result capture sets | 3.9 | bug fix | yes |
| [searchdiag](searchdiag/searchdiag.md) | Preserve an `@internal.diagnostic` candidate's errors as the search-failure message | 3.9, 3.10 | feature | yes |
| [semdiag](semdiag/semdiag.md) | `-Xsemantic-diagnostics`: XML error output with TASTy-encoded types | 3.9, 3.10 | feature | n/a |
| [skolemcap](skolemcap/skolemcap.md) | Widen skolems in retains sets to the top capability | 3.9, 3.10 | bug fix | yes (needs Soundness classpath) |
| [smap](smap/smap.md) | `-Xjsr45`: JSR-45 SMAP attributes mapping inlined code to its source files | 3.9, 3.10 | feature | n/a |
| [splicealias](splicealias/splicealias.md) | Give spliced type binders their spliced type as info | 3.9 | bug fix | yes |
| [spreadable](spreadable/spreadable.md) | Splice any type with a `Spreadable` instance into a vararg position | 3.9, 3.10 | feature | yes (2: `repro`, `repro-cc`) |
| [staleread](staleread/staleread.md) | Tolerate reading newer denotations from stale run contexts | 3.9 | bug fix (crash) | yes (needs Soundness classpath) |
| [unboxedpure](unboxedpure/unboxedpure.md) | Do not box pure types with vacuous or pure-tuple capture sets | 3.9, 3.10 | bug fix | yes |
| [unioncaps](unioncaps/unioncaps.md) | Classify and preserve capture information on union types | 3.10 | bug fix | yes |
| [virtualdir](virtualdir/virtualdir.md) | Backport the `io.virtualDirectory` factory from the 3.10 stream | 3.9 | API backport | n/a |
| [wasm](wasm/wasm.md) | WIT / WebAssembly Component Model support | 3.9, 3.10 | feature | n/a |
| [wasm-witcall](wasm-witcall/wasm-witcall.md) | `witImportCall`: stub-free WIT imports | 3.9, 3.10 | feature | n/a |

Reproductions marked "yes" are extracted verbatim from the feature docs or
from the minimal test files the patches add; they have not been re-verified
against freshly built unpatched/patched compilers from this repository.
