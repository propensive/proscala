// A singleton conforms to a union containing it under capture checking. The atoms of a
// union are cached from typing, where the prefix `this` of an object normalizes to the
// object; `Setup` gives the object's class a self type with a capture variable, so the
// singleton's own atoms kept the `this` prefix and the two never matched.

class Kind

trait Registry[-status]
class Status(val code: Int) extends caps.Pure:
  def exit(using Registry[this.type]): Int = code

object P:
  val k1 = Kind()
  val k2 = Kind()
  val e: k1.type = k1
  val f1: k1.type | k2.type = k1
  val f2: k1.type | k2.type = e
  def m(x: k1.type): k1.type | k2.type = x
  def n(x: k1.type | k2.type): k2.type | k1.type = x
  val self: P.type | k1.type = this

  class C:
    val a = Kind()
    val b = Kind()
    val t: a.type | b.type = a

  def local() =
    val p = Kind()
    val q = Kind()
    val r: p.type | q.type = p
    r

  // A union of singletons accumulated through a contravariant capability
  object A extends Status(1)
  object B extends Status(2)
  def cond: Boolean = true
  def ab(using Registry[A.type | B.type]): Int = if cond then A.exit else B.exit

def outer() =
  object E extends Status(5)
  object F extends Status(6)
  def ef(using Registry[E.type | F.type]): Int = if P.cond then E.exit else F.exit
  ef(using new Registry[Any] {})
