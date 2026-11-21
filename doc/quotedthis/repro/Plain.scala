import scala.quoted.*

abstract class Base(protected val table: Array[Int]):
  def index(key: Int): Int

object Macro:
  inline def make(inline n: Int): Base = ${impl('n)}

  def impl(n: Expr[Int])(using Quotes): Expr[Base] =
    '{
      new Base(Array(1, 2, 3)):
        def index(key: Int): Int = table(key)
    }
