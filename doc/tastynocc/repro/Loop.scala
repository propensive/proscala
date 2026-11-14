package app

enum State:
  case Active, Stopped

object Sorting:
  def boxed(raw: Array[Int]): Int =
    val boxed = new Array[AnyRef](raw.length)
    var index = 0

    while index < raw.length do
      boxed(index) = raw(index).asInstanceOf[AnyRef]
      index += 1

    boxed.length
