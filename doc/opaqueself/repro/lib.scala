package lib

class Box[+T](val value: T)

object Array:
  def size[E](xs: Array[E]^{}): Int = xs.length
  def boxed[E](xs: Array[E]^{}): Box[Array[E]^{}] = Box(xs)

opaque type Array[E] = scala.Array[E]
