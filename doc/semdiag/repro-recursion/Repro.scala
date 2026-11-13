import dotty.tools.dotc.core.Contexts.*
import dotty.tools.dotc.core.Decorators.*
import dotty.tools.dotc.core.Symbols.defn
import dotty.tools.dotc.core.Types.*
import dotty.tools.dotc.reporting.DiagnosticMarkup

// Formats, as a diagnostic message would, a type that cannot be pickled: a reference
// to a method's parameter outside the method type that binds it. With the markup
// active, formatting a type pickles it.
object Repro:
  def main(args: Array[String]): Unit =
    val base = new ContextBase
    val initial = base.initialCtx.fresh
    initial.setSetting(initial.settings.classpath, args(0))
    initial.setSetting(initial.settings.color, "never")
    base.initialize()(using initial)

    given Context =
      if args(1) == "marked" then initial.fresh.setProperty(DiagnosticMarkup.Active, ())
      else initial

    val method = MethodType(List("r".toTermName))(_ => List(defn.ObjectType), _.newParamRef(0))
    val orphan = method.resType
    println(i"formatted: $orphan".linesIterator.next().take(60))
