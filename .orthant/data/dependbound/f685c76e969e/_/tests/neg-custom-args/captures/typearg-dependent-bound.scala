import scala.language.experimental.captureChecking

class Cap extends scala.caps.SharedCapability
class Box(val cap: Cap^)
class Coll[+element]

def first[element, coll <: Coll[element]](coll: coll): Option[element] = None

def test(cap: Cap^): Unit =
  val boxes: Coll[Box^{cap}] = new Coll
  val a: Option[Box] = first[Box, Coll[Box^{cap}]](boxes) // error
  val b: Option[Box] = first(boxes) // error
  val c: Option[Box^{cap}] = first(boxes)
  val d = first(boxes)
  val e: Option[Box] = d // error
