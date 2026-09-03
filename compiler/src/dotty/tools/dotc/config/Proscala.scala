package dotty.tools.dotc
package config

import core.Contexts.*

/** Proscala's optional behaviours.
 *
 *  Each is a patch on upstream Scala that is enabled by its own flag, `-Z<name>`
 *  (`-Zliterate-literals`, `-Zunion-captures`), in the style of `-X` and `-Y`;
 *  where a feature is not enabled the compiler runs upstream's code at every
 *  site the patch touches. A bare `-Z` prints the synopsis of the names. The
 *  documentation of each patch lives on Proscala's `main` branch under
 *  `doc/<patch>/`.
 */
object Proscala:

  enum Feature(val name: String, val patch: String, val help: String):
    case AliasCaptures extends Feature("alias-captures", "aliascap",
      "Keep root capabilities global in type alias infos under capture checking.")
    case DiagnosticGivens extends Feature("diagnostic-givens", "searchdiag",
      "Report an @internal.diagnostic given's own errors as the message of a failed implicit search.")
    case GivenPrefixes extends Feature("given-prefixes", "givenprefix",
      "Seal package-object prefixes on implicit candidates, so a top-level given cannot leak an opaque type's representation.")
    case InlineSourceMaps extends Feature("inline-source-maps", "smap",
      "Emit JSR-45 SourceDebugExtension (SMAP) attributes mapping inlined code back to its source files.")
    case LiterateLiterals extends Feature("literate-literals", "literate",
      "Re-type literals through a scala.Literate instance in scope.")
    case OpaqueMutability extends Feature("opaque-mutability", "iarraypure-mutalias",
      "Classify opaque aliases over mutable types as mutable under capture checking.")
    case PureIArrays extends Feature("pure-iarrays", "iarraypure",
      "Treat IArray as pure under capture checking.")
    case RetainsBounds extends Feature("retains-bounds", "retainbounds",
      "Approximate TypeBounds in @retains arguments by the top capability.")
    case RetainsSkolems extends Feature("retains-skolems", "skolemcap",
      "Widen skolems in @retains sets to the top capability.")
    case SemanticDiagnostics extends Feature("semantic-diagnostics", "semdiag",
      "Emit diagnostics as XML with semantic markup, embedding diagnostic types as Base64-encoded TASTy.")
    case SpreadableVarargs extends Feature("spreadable-varargs", "spreadable",
      "Splice any value with a scala.Spreadable instance into a vararg position.")
    case UnboxedPureTypes extends Feature("unboxed-pure-types", "unboxedpure",
      "Do not box pure types with vacuous or pure-tuple capture sets under capture checking.")
    case UnionCaptures extends Feature("union-captures", "unioncaps",
      "Classify and preserve capture information on union types under capture checking.")
  end Feature

  export Feature.*

  /** Every feature, in the order a bare `-Z` lists them. */
  val features: List[Feature] = Feature.values.toList

  /** Is `feature` enabled with its `-Z<name>` flag in this context? */
  def enabled(feature: Feature)(using Context): Boolean =
    ctx.settings.Zfeature(feature).value

end Proscala
