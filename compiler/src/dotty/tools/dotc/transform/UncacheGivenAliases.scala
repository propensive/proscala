package dotty.tools.dotc
package transform

import MegaPhase.*
import core.DenotTransformers.{IdentityDenotTransformer}
import core.Symbols.*
import core.Contexts.*
import core.Types.*
import core.Flags.*
import ast.tpd
import config.Feature

object UncacheGivenAliases:
  val name: String = "uncacheGivenAliases"
  val description: String = "avoid caching RHS of simple parameterless given aliases"

/** This phase optimizes alias givens represented as lazy vals to be uncached
 *  if that does not change runtime behavior. A definition does not need to be
 *  cached if its right hand side has a stable type and is of one of them forms
 *
 *    this
 *    this.y
 *    y
 */
class UncacheGivenAliases extends MiniPhase with IdentityDenotTransformer:
  thisPhase =>
  import tpd.*

  override def phaseName: String = UncacheGivenAliases.name

  override def description: String = UncacheGivenAliases.description

  private def needsCache(sym: Symbol, rhs: Tree)(using Context): Boolean = rhs.tpe match
    case rhsTpe @ TermRef(NoPrefix, _)
    if rhsTpe.isStable => false
    case rhsTpe @ TermRef(pre: ThisType, _)
    if rhsTpe.isStable && pre.cls == sym.owner.enclosingClass => false
    case rhsTpe: ThisType => false
    case _ => true

  /** Transform
   *
   *    lazy given val x = rhs
   *
   *  to
   *
   *    def x = rhs
   *
   *  provided `rhs` has a stable type and is of one of them forms
   *
   *    this
   *    this.y
   *    y
   */
  override def transformValDef(tree: ValDef)(using Context): Tree =
    val sym = tree.symbol
    // Under capture checking, a stable given alias val is a trackable reference that
    // may already be named in capture sets ({x} in a retains annotation). Demoting it
    // to a def gives it an ExprType underlying, which is no longer a legal capability
    // and crashes cc Setup (IllegalCaptureRef) when a later cast or summon forces the
    // set. Skip the optimization when cc is on anywhere; semantics are unchanged.
    if sym.isAllOf(LazyGiven) && !needsCache(sym, tree.rhs)
        && !Feature.ccEnabledSomewhere then
      sym.copySymDenotation(
        initFlags = sym.flags &~ Lazy | Method,
        info = ExprType(sym.info))
      .installAfter(thisPhase)
      cpy.DefDef(tree)(tree.name, Nil, tree.tpt, tree.rhs)
    else tree
end UncacheGivenAliases


