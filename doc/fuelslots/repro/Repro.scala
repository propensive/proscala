import dotty.tools.dotc.ast.untpd
import dotty.tools.dotc.core.Contexts.*
import dotty.tools.dotc.parsing.Parsers
import dotty.tools.dotc.util.SourceFile

// Parses a sum of `n` terms and counts the nodes of its tree, with a context base
// that is never initialized: nothing here needs a classpath or definitions.
object Repro:
  def main(args: Array[String]): Unit =
    val n = args(0).toInt
    given Context = ContextBase().initialCtx.fresh
    val code = "val sum: Int = " + (1 to n).mkString(" + ")
    val tree = Parsers.Parser(SourceFile.virtual("sum.scala", code)).parse()

    val count = new untpd.UntypedTreeAccumulator[Int]:
      def apply(nodes: Int, tree: untpd.Tree)(using Context): Int = foldOver(nodes + 1, tree)

    println(s"terms $n nodes ${count(0, tree)}")
