//> using options -language:experimental.spreadable
import scala.language.experimental.spreadable
import lib.*
object NegSel:
  def bad = Series(1,2,3).head            // must fail: not a Conversion
