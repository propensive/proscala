package app

import scala.quoted.*

object Macro:
  inline def twice(inline value: Int): Int = ${ impl('value) }
  def impl(value: Expr[Int])(using Quotes): Expr[Int] = '{ $value + $value }
