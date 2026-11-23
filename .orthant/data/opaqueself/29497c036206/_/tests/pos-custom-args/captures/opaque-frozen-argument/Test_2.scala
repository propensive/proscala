import language.experimental.captureChecking
import language.experimental.separationChecking

import lib.*

def test(xs: Array[Int]^{}): Box[Array[Int]^{}] =
  val size = Array.size(xs)
  Array.boxed(xs)

def bytes(xs: Bytes^{}): Box[Bytes^{}] =
  val size = Bytes.size(xs)
  Bytes.boxed(xs)
