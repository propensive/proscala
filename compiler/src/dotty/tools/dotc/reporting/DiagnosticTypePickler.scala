package dotty.tools
package dotc
package reporting

import scala.collection.mutable
import scala.util.control.NonFatal

import ast.tpd
import core.*
import Annotations.Annotation
import Constants.Constant
import Contexts.*
import Decorators.*
import Symbols.*
import Types.*
import core.tasty.{Attributes, TastyPickler, TreePickler}

/** Pickles the types appearing in diagnostic messages to standalone TASTy, for
 *  embedding in `-Xsemantic-diagnostics` output.
 *
 *  A diagnostic type may mention things that no consumer can resolve: symbols
 *  defined in the (possibly failing) sources being compiled, error types,
 *  uninstantiated type variables, skolems. Each maximal subtree headed by such a
 *  part is replaced by a string literal type `"⟨scala-diag:<n>⟩"` before
 *  pickling and described out-of-band by a [[DiagnosticMarkup.Placeholder]], so
 *  that the pickled type always resolves against the classpath alone. Whole
 *  subtrees are replaced — not just the offending reference — because a literal
 *  type cannot stand in a type-constructor or prefix position.
 */
object DiagnosticTypePickler:

  final case class Pickled(tasty: String, placeholders: List[DiagnosticMarkup.Placeholder])

  /** The sanitized, pickled, Base64-encoded form of `tp`, or None if the type
   *  cannot be pickled. Never throws: a diagnostic must not become a crash.
   */
  def pickle(tp: Type)(using Context): Option[Pickled] =
    try
      val cleaner = Cleaner()
      val cleaned = cleaner(tp)
      val pickler = new TastyPickler(defn.RootClass, isBestEffortTasty = false)
      val treePkl = new TreePickler(pickler, Attributes.empty)
      treePkl.pickle(tpd.TypeTree(cleaned) :: Nil)
      treePkl.compactify()
      val bytes = pickler.assembleParts()
      Some(Pickled(java.util.Base64.getEncoder.encodeToString(bytes), cleaner.placeholders.toList))
    catch case NonFatal(_) => None

  private class Cleaner(using Context) extends TypeMap:
    val placeholders = mutable.ListBuffer[DiagnosticMarkup.Placeholder]()

    /** Can no consumer resolve a reference to `sym` against the classpath? */
    private def unresolvable(sym: Symbol): Boolean =
      !sym.exists || sym.isDefinedInCurrentRun

    /** Is `tp`, in head or prefix position, a part that cannot survive
     *  pickling? Conservative: the final safety net is the try/catch around
     *  the pickler.
     */
    private def unpickleableHead(tp: Type): Boolean = tp match
      case tp: NamedType   => unresolvable(tp.symbol) || unpickleableHead(tp.prefix)
      case tp: ThisType    => unpickleableHead(tp.tref)
      case tp: SuperType   => unpickleableHead(tp.thistpe)
      case tp: AppliedType => unpickleableHead(tp.tycon)
      case _: SkolemType   => true
      case _: ErrorType    => true
      case tp: TypeVar     =>
        val inst = tp.instanceOpt
        !inst.exists || unpickleableHead(inst)
      case _               => false

    def apply(tp: Type): Type = tp match
      case tp: TypeVar =>
        val inst = tp.instanceOpt
        if inst.exists then apply(inst) else placeholder(tp, "typevar")
      case tp: SkolemType => placeholder(tp, "skolem")
      case tp: ErrorType  => placeholder(tp, "error")
      case tp: NamedType =>
        if unpickleableHead(tp) then
          placeholder(tp, if tp.isType then "local-type" else "local-term")
        else mapOver(tp)
      case tp: AppliedType =>
        if unpickleableHead(tp.tycon) then placeholder(tp, "local-type")
        else mapOver(tp)
      case tp @ AnnotatedType(parent, annot) =>
        if annotOk(annot) then mapOver(tp) else apply(parent)
      case tp: ConstantType =>
        tp.value.value match
          case s: String if s.startsWith(DiagnosticMarkup.PlaceholderPrefix) =>
            ConstantType(Constant(DiagnosticMarkup.escapedLiteral(s)))
          case _ => tp
      case _ => mapOver(tp)

    /** Does the annotation reference only classpath-resolvable symbols?
     *  Unresolvable annotations are dropped rather than replaced: an
     *  annotation is not a type position a placeholder could occupy.
     */
    private def annotOk(annot: Annotation): Boolean =
      !unresolvable(annot.symbol) && {
        val hasBad = new tpd.TreeAccumulator[Boolean]:
          def apply(bad: Boolean, tree: tpd.Tree)(using Context): Boolean =
            bad
            || tree.hasType && tree.tpe.existsPart({
                 case t: NamedType => unresolvable(t.symbol)
                 case _: ErrorType => true
                 case _            => false
               })
            || foldOver(bad, tree)
        !hasBad(false, annot.tree)
      }

    private def placeholder(tp: Type, kind: String): Type =
      val id = placeholders.length
      val sym = tp match
        case tp: NamedType   => tp.symbol
        case tp: AppliedType => tp.tycon.typeSymbol
        case _               => NoSymbol
      val arity = tp match
        case tp: AppliedType => tp.args.length
        case _               => 0
      val definedAt =
        try
          if sym.exists && sym.span.exists && sym.source.exists
          then s"${sym.source.file.path}:${sym.sourcePos.line + 1}"
          else ""
        catch case NonFatal(_) => ""
      val printed = try tp.show catch case NonFatal(_) => ""
      placeholders += DiagnosticMarkup.Placeholder(
        id, kind, if sym.exists then sym.name.show else "", arity, definedAt, printed)
      ConstantType(Constant(DiagnosticMarkup.placeholderText(id)))
