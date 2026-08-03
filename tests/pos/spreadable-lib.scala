//> using options -language:experimental.spreadable
package lib
import scala.language.experimental.spreadable

// 1. opaque alias over a Seq — the zero-cost case
object Series:
  def apply[e](es: e*): Series[e] = es.toVector
  given [e] => (Spreadable[Series[e]] { type Out = Vector[e] }) =
    new Spreadable[Series[e]]:
      type Out = Vector[e]
      def spread(value: Series[e]): Vector[e] = value      // identity here
opaque type Series[+e] = Vector[e]

// 2. opaque alias over IArray — the wildcard-array case
object Data:
  def apply(bs: Byte*): Data = IArray(bs*)
  given (Spreadable[Data] { type Out = IArray[Byte] }) =
    new Spreadable[Data]:
      type Out = IArray[Byte]
      def spread(value: Data): IArray[Byte] = value
opaque type Data = IArray[Byte]

// 3. a genuinely different type — needs a real conversion
class Trie[e](val items: List[e])
object Trie:
  given [e] => (Spreadable[Trie[e]] { type Out = Seq[e] }) =
    new Spreadable[Trie[e]]:
      type Out = Seq[e]
      def spread(value: Trie[e]): Seq[e] = value.items

// 4. an opaque alias with NO instance — must stay unspreadable
object Secret:
  def apply[e](es: e*): Secret[e] = es.toVector
opaque type Secret[+e] = Vector[e]
