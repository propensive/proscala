import scala.quoted.*

object Macro:
  inline def greeting: String = ${ impl }
  def impl(using Quotes): Expr[String] = Expr("hello")
  // Boxing here attaches the @ValueBased annotation to java.lang.Integer in
  // the first run, so that the second run finds a symbol from the first.
  val boxed: Any = 1
