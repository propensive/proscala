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

import language.experimental.into
import language.experimental.pureFunctions

import java.lang as jl
import java.net.{URLEncoder, URLDecoder}
import java.util.regex as jur

import scala.collection.mutable as scm
import scala.reflect.*

import anticipation.*
import denominative.*
import distillate.*
import fulminate.*
import hieroglyph.*
import hypotenuse.*
import kaleidoscope.*
import prepositional.*
import rudiments.*
import spectacular.*
import symbolism.*
import vacuous.*

import Textual.concatenable

extension (inline context: StringContext)
  transparent inline def t(inline parts: Any*): Text =
    ${gossamer.internal.t('context, 'parts)}

extension [textual](text: textual)
  def cut[delimiter](delimiter: delimiter, limit: Int = Int.MaxValue)
    ( using cuttable: textual is Cuttable by delimiter )
  :   List[textual] =
    cuttable.cut(text, delimiter, limit)

extension [textual: Textual](text: textual)
  inline def length: Int = textual.length(text)
  def justify(width: Int): textual =
    val extra = width - text.length
    def recur(word: Ordinal, spaces: Int, result: textual): textual =
        val gap = ((spaces.toDouble/word.n0) + 0.5).toInt
        recur(word - 1, spaces - gap, result+textual(t" "*(gap + 1))+words(words.length - word.n0))
    recur(Prim, extra, words(0))
  def words: List[textual] = text.cut(" ".tt)
extension [textual: Textual { type Result = Char }](text: textual)
  inline def tr(from: Char, to: Char): textual =
    textual.map(text): char => if char == from then to else char
package proximities:
  given jaroProximity: (sensitivity: CaseSensitivity) => Proximity by Double = (left, right) =>
      val maxDist: Int = left.length.max(right.length)/2 - 1
      val found1 = new scm.BitSet(left.length)
      val found2 = new scm.BitSet(right.length)
      @tailrec
      def recur(i: Int, j: Int, matches: Int): Int =
        if i >= left.length then matches else
          if j >= (i + maxDist + 1).min(right.length)
          then recur(i + 1, (i + 1 - maxDist).max(0), matches)
          else if sensitivity.compare(left.s.charAt(i), right.s.charAt(j)) && !found2(j) then
            recur(i + 1, (i + 1 - maxDist).max(0), matches + 1)
          else
            recur(i, j + 1, matches)

      val matches = recur(0, 0, 0)

      def transform(i: Int, j: Int, count: Int): Int =
        if i >= left.length then count else if found1(i) then
          def next(j: Int): Int = if found2(j) then j else next(j + 1)
          val j2 = next(j)

          transform(i + 1,
                j2 + 1,
                if sensitivity.compare(left.s.charAt(i), right.s.charAt(j2))
                then count
                else count + 1)

        else
          transform(i + 1, j, count)

      val count = transform(0, 0, 0)

      if matches == 0 then 0.0 else
        ( matches.toDouble/left.length + matches.toDouble/right.length +
          (matches - count/2.0)/matches ) /
          3

