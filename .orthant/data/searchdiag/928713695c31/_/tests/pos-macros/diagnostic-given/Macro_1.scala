import scala.quoted.*
import scala.annotation.internal.diagnostic

object Macros:
  transparent inline def explanation[T]: T = ${explanationImpl[T]}

  def explanationImpl[T: Type](using Quotes): Expr[T] =
    quotes.reflect.report.errorAndAbort("CUSTOM DIAGNOSTIC: " + Type.show[T])

object Givens:
  @diagnostic
  transparent inline given explain: [T] => T = Macros.explanation[T]
