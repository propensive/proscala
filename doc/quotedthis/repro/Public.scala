import scala.quoted.*

abstract class Base(val table: Array[Int]):
  def index(key: Int): Int

object Macro:
  inline def make(inline n: Int): Base = ${impl('n)}

  def body(key: Expr[Int], table: Expr[Array[Int]])(using Quotes): Expr[Int] = '{$table($key)}

  def impl(n: Expr[Int])(using Quotes): Expr[Base] =
    '{
      new Base(Array(1, 2, 3)):
        def index(key: Int): Int = ${body('key, '{table})}
    }
