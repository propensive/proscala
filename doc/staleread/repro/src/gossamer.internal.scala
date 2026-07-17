                                                                                                  /*
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                                                                                  ┃
┃                                                   ╭───╮                                          ┃
┃                                                   │   │                                          ┃
┃                                                   │   │                                          ┃
┃   ╭───────╮╭─────────╮╭───╮ ╭───╮╭───╮╌────╮╭────╌┤   │╭───╮╌────╮╭────────╮╭───────╮╭───────╮   ┃
┃   │   ╭───╯│   ╭─╮   ││   │ │   ││   ╭─╮   ││   ╭─╮   ││   ╭─╮   ││   ╭─╮  ││   ╭───╯│   ╭───╯   ┃
┃   │   ╰───╮│   │ │   ││   │ │   ││   │ │   ││   │ │   ││   │ │   ││   ╰─╯  ││   ╰───╮│   ╰───╮   ┃
┃   ╰───╮   ││   │ │   ││   │ │   ││   │ │   ││   │ │   ││   │ │   ││   ╭────╯╰───╮   │╰───╮   │   ┃
┃   ╭───╯   ││   ╰─╯   ││   ╰─╯   ││   │ │   ││   ╰─╯   ││   │ │   ││   ╰────╮╭───╯   │╭───╯   │   ┃
┃   ╰───────╯╰─────────╯╰────╌╰───╯╰───╯ ╰───╯╰────╌╰───╯╰───╯ ╰───╯╰────────╯╰───────╯╰───────╯   ┃
┃                                                                                                  ┃
┃    Soundness, version 0.63.0.                                                                    ┃
┃    © Copyright 2021-25 Jon Pretty, Propensive OÜ.                                                ┃
┃                                                                                                  ┃
┃    The primary distribution site is:                                                             ┃
┃                                                                                                  ┃
┃        https://soundness.dev/                                                                    ┃
┃                                                                                                  ┃
┃    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file     ┃
┃    except in compliance with the License. You may obtain a copy of the License at                ┃
┃                                                                                                  ┃
┃        https://www.apache.org/licenses/LICENSE-2.0                                               ┃
┃                                                                                                  ┃
┃    Unless required by applicable law or agreed to in writing,  software distributed under the    ┃
┃    License is distributed on an "AS IS" BASIS,  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    ┃
┃    either express or implied. See the License for the specific language governing permissions    ┃
┃    and limitations under the License.                                                            ┃
┃                                                                                                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
                                                                                                  */
package gossamer

import scala.quoted.*

import anticipation.*
import denominative.*
import fulminate.*
import gigantism.*
import hieroglyph.*
import kaleidoscope.*
import rudiments.*
import spectacular.*
import symbolism.*
import vacuous.*

object internal:
  // Both `t""` and `txt""` build a Text by escape-processing each static part
  // at compile time and converting each substitution via Showable at runtime.
  // Only the final treatment differs: txt collapses runs of whitespace and
  // double-newlines into single newlines for multi-line literals.
  private def textInterpolator
    ( context:    Expr[StringContext],
     insertions: Expr[Seq[Any]],
     normalize:  Boolean )
    ( using Quotes )
  :   Expr[Text] =

    import quotes.reflect.*

    val rawParts: List[String] =
      context.value.getOrElse:
        halt(m"the StringContext extension method parameter does not appear to be inline")

      . parts.toList

    val escapedParts: List[String] = rawParts.map: part =>
      try TextEscapes.escape(part.tt).s catch case error: EscapeError => error match
        case EscapeError(msg) => halt(msg)

    val insertionExprs: List[Expr[Any]] = insertions.absolve match
      case Varargs(exprs) => exprs.toList

    val showedInsertions: List[Expr[String]] = insertionExprs.map: expr =>
      expr.absolve match
        case '{$value: tpe} =>
          Expr.summon[(? >: tpe) is Showable] match
            case Some('{$showable: Showable}) =>
              '{$showable.text($value).s}

            case _ =>
              halt(m"a value of ${TypeRepr.of[tpe].show} is not Showable")

    var concatExpr: Expr[String] = Expr(escapedParts.head)
    var i = 0

    while i < showedInsertions.length do
      val insertion = showedInsertions(i)
      val nextPart = Expr(escapedParts(i + 1))
      concatExpr = '{$concatExpr + $insertion + $nextPart}
      i += 1

    if normalize then
      ' {
          val array =
            $concatExpr.split("\\n\\s*\\n").nn.map(_.nn.replaceAll("\\s\\s*", " ").nn.trim.nn)

          anticipation.Text(String.join("\n", array*).nn)
        }
    else
      '{anticipation.Text($concatExpr)}


  def t(context: Expr[StringContext], insertions: Expr[Seq[Any]]): Macro[Text] =
    textInterpolator(context, insertions, normalize = false)


