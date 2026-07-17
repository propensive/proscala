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

import anticipation.*
import denominative.*
import prepositional.*
import rudiments.*
import symbolism.*
import vacuous.*

object Textual:
  given concatenable: [textual: Textual] => textual is Concatenable:
    type Operand = textual
    def concat(left: textual, right: textual): textual = textual.concat(left, right)
  given text: Text is Textual:
    type Result = Char
    def length(text: Text): Int = text.s.length
    def apply(text: Text): Text = text
    def map(text: Text)(lambda: Char => Char): Text = Text(text.s.map(lambda))
    def segment(text: Text, interval: Interval): Text =
      val limit = length(text)
      val start = interval.start.n0.max(0).min(limit)
      val end = interval.limit.n0.max(start).min(limit)

      text.s.substring(start, end).nn.tt

    def empty: Text = Text("")
    def concat(left: Text, right: Text): Text = Text(left.s+right.s)
    def access(text: Text, index: Ordinal): Char = text.s.charAt(index.n0)
    def indexOf(text: Text, sub: Text, start: Ordinal): Optional[Ordinal] =
      text.s.indexOf(sub.s, start.n0).puncture(-1).let(_.z)
    def size(text: Self): Int = text.length

trait Textual extends Typeclass.Pure, Countable, Segmentable, Zeroic, Indexable:
  type Operand = Ordinal
  def apply(text: Text): Self
  def length(text: Self): Int
  def map(text: Self)(lambda: Result => Result): Self
  def empty: Self
  def concat(left: Self, right: Self): Self
  def contains(text: Self, index: Ordinal): Boolean = index.n0 >= 0 && index.n0 < length(text)
  def indexOf(text: Self, sub: Text, start: Ordinal = Prim): Optional[Ordinal]
  inline def zero: Self = empty
