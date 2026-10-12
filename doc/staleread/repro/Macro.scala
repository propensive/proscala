import scala.quoted.*

object Macro:
  def succ(x: Expr[Int])(using Quotes): Expr[Int] = '{$x + 1}
