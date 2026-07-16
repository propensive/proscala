import scala.quoted.*
object Internal:
  def amount[U: Type](using Quotes): Expr[String] = Expr(Type.show[U])
