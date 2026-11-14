package app

object Ordinals:
  extension (index: Int) inline def twice: Int = index + index

inline trait Counter[operand]:
  import Ordinals.*

  var count: Int = 1

  def advance(): Unit = count = count.twice

class Doubler extends Counter[Byte]

object Main:
  def main(args: Array[String]): Unit =
    val doubler = Doubler()
    doubler.advance()
    println(doubler.count)
