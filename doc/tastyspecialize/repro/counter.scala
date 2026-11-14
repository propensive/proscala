package app

import Counting.*

object Counting:
  extension (count: Int) inline def twice: Int = count + count

inline trait Counter[operand]:
  var count: Int = 1

  def advance(): Unit = count = count.twice

class Doubler extends Counter[Byte]

object Main:
  def main(args: Array[String]): Unit =
    val doubler = Doubler()
    doubler.advance()
    doubler.advance()
    println(doubler.count)
