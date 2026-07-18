package app

import scala.quoted.*
import lib.*

def build(using Quotes): Expr[IArray[String]] =
  val names: Lst[Expr[String]] = Lst.range(0, 3).map(n => Expr(n.toString))
  '{ IArray[String](${Varargs[String](names)}*) }
