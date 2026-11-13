// An inline extension of an opaque type, called on a value whose type names the
// opaque type through an alias that `widenDealias` does not follow: below a
// refinement, or as a type argument.

package minipkg

object mini:
  opaque type O = Int
  extension (inline o: O)
    inline def next: Int = o + 1
  extension (os: List[O])
    inline def total: Int = os.sum
  object O:
    def mint(i: Int): O = i

export mini.O

object Use:
  def refined(o: O { type Form = Int }): Int = o.next
  def argument(os: List[O]): Int = os.total
  def plain(o: O): Int = o.next
  def direct(o: mini.O { type Form = Int }): Int = o.next
