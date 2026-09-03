# `-Z`: enable Proscala's optional behaviours by name

Adds one compiler setting, `-Z:<name>,...`, through which a build enables each
of the fork's opt-in behaviours by name; where a name is not given, the
compiler runs upstream's code at every site the corresponding patch touches.
`-Z:help` lists the names, and an unknown name is an error.

## Context

Proscala's patches fall into two groups. Most are fixes for a crash, a hang or
a spurious error: for code that compiled before they change nothing, and for
code that did not there is no "upstream behaviour" worth selecting, so they are
always on. The rest change what the compiler *produces* for code it already
accepted — the inferred capture sets pickled into TASTy, the type of a
literal, the classfile's debug attributes — or reject code upstream accepts. A
Soundness module needs only a few of those, and the fewer it enables, the more
of its compilation is the standard compiler's and the more its artifacts can
be trusted to match vanilla output. [compatibility.md](../compatibility.md)
assesses the consequences of each.

Before this change two such features already had flags of their own
(`-Xsemantic-diagnostics`, `-Xjsr45`) and the others were unconditional.

## The setting

`-Z` is a multi-choice setting in a new `ProscalaSetting` category (prefix
letter `Z`, alongside upstream's `X`, `Y`, `W` and `V`). Its choices come from
one registry, `dotty.tools.dotc.config.Proscala`:

```scala
object Proscala:
  enum Feature(val name: String, val patch: String, val help: String):
    case LiterateLiterals extends Feature("literate-literals", "literate",
      "Re-type literals through a scala.Literate instance in scope.")
    ...
  def enabled(feature: Feature)(using Context): Boolean =
    ctx.settings.Z.value.contains(feature.name)
```

A gated patch tests its feature at each site it changes, keeping upstream's
code as the other branch:

```scala
// cc/CapturingType.scala, the unioncaps patch
if refs.isAlwaysEmpty && !parent.isAny && !refs.keepAlways
   && !(if config.Proscala.enabled(config.Proscala.UnionCaptures) then hasCapabilityPart(parent)
        else parent.derivesFromCapability)
then parent
```

The names, one per gated patch:

| `-Z:` name | Patch | Enables |
| --- | --- | --- |
| `alias-captures` | [aliascap](../aliascap/aliascap.md) | root capabilities stay global in type alias infos |
| `diagnostic-givens` | [searchdiag](../searchdiag/searchdiag.md) | an `@internal.diagnostic` given's errors become the search-failure message |
| `given-prefixes` | [givenprefix](../givenprefix/givenprefix.md) | package-object prefixes sealed on implicit candidates |
| `inline-source-maps` | [smap](../smap/smap.md) | JSR-45 SMAP attributes for inlined code |
| `literate-literals` | [literate](../literate/literate.md) | literals re-typed through `Literate` instances |
| `opaque-mutability` | [iarraypure-mutalias](../iarraypure-mutalias/iarraypure-mutalias.md) | opaque aliases over mutable types classified as mutable |
| `pure-iarrays` | [iarraypure](../iarraypure/iarraypure.md) | `IArray` treated as pure |
| `retains-bounds` | [retainbounds](../retainbounds/retainbounds.md) | `TypeBounds` in `@retains` approximated by the top capability |
| `retains-skolems` | [skolemcap](../skolemcap/skolemcap.md) | skolems in `@retains` widened to the top capability |
| `semantic-diagnostics` | [semdiag](../semdiag/semdiag.md) | XML diagnostics with TASTy-encoded types |
| `spreadable-varargs` | [spreadable](../spreadable/spreadable.md) | `Spreadable` values spliced into vararg positions |
| `unboxed-pure-types` | [unboxedpure](../unboxedpure/unboxedpure.md) | no boxing of pure types with vacuous capture sets |
| `union-captures` | [unioncaps](../unioncaps/unioncaps.md) | capture information classified and preserved on unions |

## The base branch

The registry is the one file several patches would otherwise all edit, and
concurrent edits to one region are exactly what makes a trunk rebuild
conflict. So `-Z` is not a patch: it is the **stream base**, branch
`feature/<stream>/zflags`, rebased onto `upstream/<stream>`, with every
patch rebased onto it and `trunk/<stream>` built on it.
`bin/proscala-rebase-tree` knows the slot (it is the one the old
`feature/<stream>/make` build branch occupied), and `zflags` is not listed in
`features/<stream>`. Adding a gated patch means one edit to the registry on
the base and the gate in the patch itself; a patch that needs no flag simply
never mentions the base.

The cost of a gate is that a patch now carries upstream's code as its
else-branch, so when upstream edits those lines the patch's rebase conflicts
where a one-line replacement would have merged. That is why only patches whose
off state is a meaningful choice are gated; the always-on fixes are left as
plain replacements.

## Choosing flags for a module

Enable the features a module's source needs (`literate-literals` where it
relies on `Text` literals, say) and, for a capture-checked module, the
capture-set features consistently across every module that shares TASTy: the
flags in the `pure-iarrays` to `union-captures` group change the capture
annotations pickled into a module's artifacts, and a downstream module reading
them with the flag off applies different rules to the same types. See
[compatibility.md](../compatibility.md) for the rule and its consequences.
