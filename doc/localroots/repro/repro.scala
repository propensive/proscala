import language.experimental.captureChecking
import scala.caps

class Sextant extends caps.ExclusiveCapability:
  def read(): Int = 42

trait Debufferable[t]:
  def debuffer(sextant: Sextant): t

given Debufferable[Int]:
  def debuffer(sextant: Sextant): Int = sextant.read()

class Join[t](val debuffer0: Sextant -> t) extends Debufferable[t]:
  def debuffer(sextant: Sextant): t = debuffer0(sextant)

inline def build[t](inline lambda: Debufferable[Int] ?=> t): t = lambda(using scala.compiletime.summonInline[Debufferable[Int]])

inline def conjunction[t]: Debufferable[t]^ =
  Join(sextant => build { summon[Debufferable[Int]].debuffer(sextant) }).asInstanceOf[Debufferable[t]]

inline def unpackFrom[t](offset: Int): t = conjunction[t].debuffer(Sextant())

def let[a, b](x: a)(lambda: a => b): b = lambda(x)

case class Pair(x: Int, y: Int)
def direct: Pair = unpackFrom[Pair](0)
def direct2: Pair = unpackFrom[Pair](1)
