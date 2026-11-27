import scala.language.experimental.captureChecking

class Cap extends scala.caps.SharedCapability
class Box(val cap: Cap^)
class Coll[+element]

trait Sized[self, element] extends scala.caps.Pure:
  def size(self: self): Int

object Sized:
  given coll: [element, coll <: Coll[element]] => Sized[coll, element] = _ => 0

extension [self, element](self: self)(using sized: Sized[self, element])
  def size: Int = sized.size(self)

def test(cap: Cap^): Int =
  val boxes: Coll[Box^{cap}] = new Coll
  boxes.size
