package minirepro

import scala.collection.immutable as sci

object Lst:
  def of[e](list: sci.List[e]): Lst[e] = list.asInstanceOf[Lst[e]]

val Nul: Lst[Nothing] = Lst.of(sci.Nil)

given consConstructor: Object with
  extension [element](head: element)
    infix def ::(tail: Lst[element]): Lst[element] =
      Lst.of(tail.asInstanceOf[sci.List[element]].::(head))

opaque type Lst[+element] = sci.List[element]
