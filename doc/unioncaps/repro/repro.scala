import language.experimental.captureChecking
import language.experimental.separationChecking
type U = Int | Array[Int]^{} | Array[Long]^{}
object O:
  def m(): U = 1
  def use(): U =
    val r = m()
    r
