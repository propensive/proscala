//> using options -experimental -language:experimental.inlineTraits

// A unit which declares an inline trait and a class which extends it. Read back from
// TASTy, it was not marked as having specializations, as `CheckInlineTraits` marks a
// unit compiled from source: the trait's body kept its inline calls ("declared as
// inline, but was not inlined"), and the class called an initializer the trait does
// not have.

import Counting.*

object Counting:
  extension (count: Int) inline def twice: Int = count + count

inline trait Counter[operand]:
  var count: Int = 1

  def advance(): Unit = count = count.twice

class Doubler extends Counter[Byte]

object Test:
  def main(args: Array[String]): Unit =
    val doubler = Doubler()
    doubler.advance()
    doubler.advance()
    println(doubler.count)
