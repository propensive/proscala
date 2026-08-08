package mini

import scala.quoted.*

trait TC:
  type Result
  def result: Result

object TC:
  given text: [element] => TC:
    type Result = Char
    def result: Result = 'x'

extension (value: String)(using tc: TC)
  transparent inline def get: Option[tc.Result] = Some(tc.result)

object MiniMacro:
  def id(expr: Expr[Any])(using Quotes): Expr[Any] =
    expr match
      case '{$v: t} => '{$v: t}

transparent inline def id(inline any: Any): Any = ${MiniMacro.id('any)}
