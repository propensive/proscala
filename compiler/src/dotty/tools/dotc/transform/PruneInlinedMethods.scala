package dotty.tools.dotc
package transform

import core._
import Contexts._
import DenotTransformers.InfoTransformer
import Flags._
import SymDenotations._
import Symbols._
import MegaPhase.MiniPhase
import ast.tpd
import dotty.tools.dotc.core.StdNames.str
import dotty.tools.dotc.core.Types._

class PruneInlinedMethods extends MiniPhase with InfoTransformer { thisTransform =>
  import tpd._
  import PruneInlinedMethods._

  override def phaseName: String = PruneInlinedMethods.name

  override def description: String = PruneInlinedMethods.description

  override def transformInfo(tp: Type, sym: Symbol)(using Context) = tp match {
    case clsInfo: ClassInfo if sym.isClass && !sym.is(Package) && !sym.is(JavaDefined) => 
      clsInfo.derivedClassInfo(decls =
          clsInfo.decls.filteredScope(!isDeletable(_))
      )
    case _ => tp
  }

  override def transformTemplate(tree: Template)(using Context): Tree = 
    cpy.Template(tree)(body = tree.body.flatMap({
      case stmt: DefDef if isDeletable(stmt.symbol) => None
      case stmt => Some(stmt)
    }))

  private def isDeletable(sym: Symbol)(using Context): Boolean =
    // Pre-filter on the last known denotation, without advancing it: this
    // transform runs on every class denotation brought forward past it, so an
    // ordinary `sym.denot` access here replays the intervening info
    // transforms and runs completers at arbitrary points — including, in the
    // second run of a compilation-suspension restart, completers that resolve
    // symbols of the first run, which fails with a StaleSymbolException. A
    // symbol that is uncompleted, or not an inline method, cannot be a
    // specialized inline method awaiting pruning (those are created and
    // completed earlier in the same run), so only genuine candidates reach
    // the full check.
    val lastDenot = sym.lastKnownDenotation
    lastDenot.isCompleted
    && lastDenot.flagsUNSAFE.isAllOf(InlineMethod)
    && !lastDenot.flagsUNSAFE.is(JavaDefined)
    && Specialization.isSpecializedMethod(sym)
}

object PruneInlinedMethods {
  import tpd._

  val name: String = "pruneInlinedMethods"
  val description: String = "drop methods which have already been inlined" // We can't wait until erasure because they can be broken by pruneInlineTraits removing members from the specialized traits they instantiate
}
