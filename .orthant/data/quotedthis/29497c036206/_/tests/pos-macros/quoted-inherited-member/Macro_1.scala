// Members which a class defined in a quote inherits, referred to through its `this`:
// directly in the quote, where a protected one needs no accessor, and from quotes
// nested in a splice, where the reference is captured as one to a local of the quote.

import scala.quoted.*

abstract class Base(protected val table: Array[Int], val open: Array[Int]):
  var count: Int = 0
  protected def scale(n: Int): Int = n*10
  def twice(n: Int): Int = n*2
  def index(key: Int): Int

object Macro:
  def at(key: Expr[Int], table: Expr[Array[Int]])(using Quotes): Expr[Int] = '{$table($key)}
  def same[T](expr: Expr[T])(using Quotes): Expr[T] = expr

  // an inherited protected member, with no nested splice
  inline def plain: Base = ${plainImpl}
  def plainImpl(using Quotes): Expr[Base] =
    '{
      new Base(Array(1, 2, 3), Array(4, 5, 6)):
        def index(key: Int): Int = table(key) + scale(key)
    }

  // inherited members in quotes nested in a splice
  inline def nested: Base = ${nestedImpl}
  def nestedImpl(using Quotes): Expr[Base] =
    '{
      new Base(Array(1, 2, 3), Array(4, 5, 6)):
        def index(key: Int): Int =
          ${same('{count = count + 1})}
          ${at('key, '{table})} + ${at('key, '{open})} + ${at('key, '{this.open})}
          + ${same('{scale(key)})} + ${same('{twice(key)})} + ${same('{this.twice(key)})}
    }

  // the same member of two classes of the quote, in one splice
  inline def two: Base = ${twoImpl}
  def twoImpl(using Quotes): Expr[Base] =
    '{
      new Base(Array(1, 2, 3), Array(4, 5, 6)):
        outer =>
        def index(key: Int): Int =
          val inner = new Base(Array(7, 8, 9), Array(10, 11, 12)):
            def index(key: Int): Int = ${same('{open(key)*100 + outer.open(key)})}
          inner.index(key)
    }
