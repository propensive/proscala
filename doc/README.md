# Feature documentation

One subdirectory per feature. Each `doc/<feature>/` contains the feature's
documentation (`<feature>.md`) and, for bug fixes, a `repro/` directory with a
minimal reproduction — either standalone source files with a `README.md`
giving the compiler flags and expected failure, or a `FIXME.md` where no
self-contained reproduction is known yet. The same documentation applies to
every stream that carries the feature; where streams genuinely differ, the
directory carries a variant file (currently only `iarraypure`, whose 3.8
implementation differs).

| Feature | Description | Streams | Kind | Repro |
| ------- | ----------- | ------- | ---- | ----- |
| [aliascap](aliascap/aliascap.md) | Keep root capabilities global in type alias infos | 3.8, 3.9, 3.10 | bug fix | FIXME |
| [boundscap](boundscap/boundscap.md) | Keep TypeBounds out of capability wrapping in CC Setup | 3.8 | bug fix (crash) | FIXME (none known) |
| [castbox](castbox/castbox.md) | Box opaque-external type arguments in cast type applications | 3.8, 3.9 | bug fix | yes |
| [ctxresult](ctxresult/ctxresult.md) | Context-result closures level-checked at the method's level | 3.8, 3.9, 3.10 | bug fix | yes |
| [dictcaps](dictcaps/dictcaps.md) | Infer the capture set of recursive-implicit dictionary instances | 3.8, 3.9, 3.10 | bug fix | yes |
| [iarraypure](iarraypure/iarraypure.md) | Treat `IArray` as pure under capture checking | 3.8, 3.9, 3.10 | bug fix | yes |
| [inertcache](inertcache/inertcache.md) | Cache inert types in capture-checking Setup | 3.9, 3.10 | bug fix (hang) | FIXME |
| [inlineupdate](inlineupdate/inlineupdate.md) | Propagate update classification to inline accessors | 3.8, 3.9, 3.10 | bug fix | yes |
| [inlineupdate-receiver](inlineupdate-receiver/inlineupdate-receiver.md) | Judge inline receiver proxies by their underlying capture set | 3.9 | bug fix | FIXME |
| [integratemap](integratemap/integratemap.md) | Evaluate IntegrateMap symbols in the spliced run context | 3.10 | bug fix (crash) | yes |
| [lazycycle](lazycycle/lazycycle.md) | Guard against cyclic LazyRef graphs in capture-checking Setup | 3.9, 3.10 | bug fix (crash) | FIXME |
| [make](make/make.md) | The Makefile-based default build | 3.8, 3.9, 3.10 | build | n/a |
| [nullreceiver](nullreceiver/nullreceiver.md) | Widen bottom-typed call receivers to Object in the backend | 3.9, 3.10 | bug fix (crash) | yes |
| [permitlazy](permitlazy/permitlazy.md) | Lazy resolution of permitted subclasses in classfile parsing | 3.9, 3.10 | bug fix | yes |
| [sambox](sambox/sambox.md) | Capability-implied captures on SAM anonymous-class type members | 3.8, 3.9, 3.10 | bug fix | yes |
| [samstateful](samstateful/samstateful.md) | Read-only views of constant method-result capture sets | 3.9 | bug fix | yes |
| [skolemcap](skolemcap/skolemcap.md) | Widen skolems in retains sets to the top capability | 3.8, 3.9, 3.10 | bug fix | FIXME (none known) |
| [splicealias](splicealias/splicealias.md) | Give spliced type binders their spliced type as info | 3.8, 3.9 | bug fix | yes |
| [staleread](staleread/staleread.md) | Tolerate reading newer denotations from stale run contexts | 3.9 | bug fix (crash) | FIXME |
| [unboxedpure](unboxedpure/unboxedpure.md) | Do not box pure types with vacuous or pure-tuple capture sets | 3.8, 3.9, 3.10 | bug fix | yes |
| [wasm](wasm/wasm.md) | WIT / WebAssembly Component Model support | 3.8, 3.9, 3.10 | feature | n/a |
| [wasm-witcall](wasm-witcall/wasm-witcall.md) | `witImportCall`: stub-free WIT imports | 3.8, 3.9, 3.10 | feature | n/a |

Reproductions marked "yes" are extracted verbatim from the feature docs or
from the minimal test files the patches add; they have not been re-verified
against freshly built unpatched/patched compilers from this repository.
