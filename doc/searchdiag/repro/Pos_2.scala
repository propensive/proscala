import scala.util.NotGiven
import scala.compiletime.summonFrom
import Givens.given

trait Missing
class Cfg

def withDefault(using c: Cfg = new Cfg) = c

inline def choose: Int =
  summonFrom:
    case _: Missing => 1
    case _ => 2

def test =
  summon[NotGiven[Missing]]
  withDefault
  assert(choose == 2)
