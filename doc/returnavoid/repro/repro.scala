package iss1428min2

import scala.quoted.*
import language.experimental.captureChecking

trait Html { type Topic }

trait Renderable:
  type Self
  type Result
  def render(v: Self): Html { type Topic = Result }

object Macros:
  def impl[T: Type](expr: Expr[T])(using Quotes): Expr[Html] =
    expr match
      case '{ $e: value } =>
        Expr.summon[Renderable { type Self >: value }] match
          case Some(r) => '{ $r.render($e) }
          case None    => '{ new Html { type Topic = Unit } }
