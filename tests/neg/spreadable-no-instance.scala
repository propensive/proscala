//> using options -language:experimental.spreadable
import scala.language.experimental.spreadable
import lib.*
object Neg:
  def sum(xs: Int*): Int = xs.sum
  def bad = sum(Secret(1,2,3)*)           // must fail: no Spreadable instance
