package repro

import scala.quoted.*

object opt:
  opaque type Unset <: Matchable = Null
  val Unset: Unset = null

export opt.Unset
type Optional[value] = Unset | value

object macros:
  transparent inline def pick(inline flag: Boolean): Optional[String] = ${pickImpl('flag)}
  def pickImpl(flag: Expr[Boolean])(using Quotes): Expr[Optional[String]] =
    if flag.valueOrAbort then '{ "yes" } else '{ Unset }
