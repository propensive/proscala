package app

object Reader:
  def count(counter: lib.Counter[Byte]): Int =
    counter.advance()
    counter.count
