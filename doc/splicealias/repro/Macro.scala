// Macro.scala — compiled separately
import scala.quoted.*

trait TC:
  type Self
  def get: Self

object Macro:
  inline def make[T]: TC { type Self = T } = ${ makeImpl[T] }

  def makeImpl[T: Type](using Quotes): Expr[TC { type Self = T }] =
    '{ new TC { type Self = T; def get: Self = null.asInstanceOf[Self] } }
