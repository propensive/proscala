// As tests/pos/opaque-inline-export-alias.scala, under capture checking, where the
// uncast receiver showed as a mismatch against the opaque type's underlying type.

package minipkg

infix type in [refined, form <: AnyKind] = refined { type Form = form }

object mini:
  opaque type O = Int
  extension (inline o: O)
    inline def n0: Int = o
  object O:
    def mint(i: Int): O = i

export mini.O

extension [element](value: List[element])
  inline def iter(inline lambda: (O in value.type) => Unit): Unit =
    var index: Int = 0
    while index < value.length do
      lambda(mini.O.mint(index).asInstanceOf[O in value.type])
      index += 1

object Use:
  def g(xs: List[Int])(f: Int => Char): Unit = xs.iter { i => f(i.n0) }
