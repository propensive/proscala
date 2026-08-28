package repro

import scala.quoted.*
import repro.textual.Text
import repro.prelude.literate           // the literate given IS in scope here

object M:
  inline def check(inline t: (String, Any)): String = ${impl('t)}

  def impl(t: Expr[(String, Any)])(using Quotes): Expr[String] =
    t match
      case '{("", $v: Int)}         => Expr("matched-empty-literal-case")
      case '{($k: String, $v: Int)} => Expr("fell-through-to-generic")
      case _                        => Expr("no-match")
