//> using options -Zfrozen-pure -Zopaque-mutability
import language.experimental.captureChecking
import caps.*

// Under `-Zfrozen-pure` a stateful type with an explicit empty capture set -- a frozen
// `Array[T]^{}`, or an opaque alias over one -- is pure: no capability is reachable through
// it, so no `update` is. Each of these previously stamped a fresh `^{any.rd}` on the alias
// (Setup's implied-capability set), making every holder a capability.
object FrozenPure:
  def frozen[T](consume a: Array[T]^): Array[T]^{} = freeze(a)
  val literal: Array[Int]^{} = frozen(Array(1, 2, 3))

  // 1. An opaque alias over a frozen array, in its defining scope and outside it.
  object Impl:
    opaque type Digits = Array[Int]^{}
    object Digits:
      def apply(xs: Int*): Digits = frozen(xs.toArray)
      val zero: Digits = Digits(0, 0)          // was `Digits^{any.rd}`
      extension (d: Digits) def first: Int = d(0)
  import Impl.*
  class PureHolder(d: Digits):
    val digits: Digits = d
    val backup: Digits = Digits.zero

  // 2. A frozen field inside a Mutable class, whose `this` stays exclusive.
  final class Reader(data: Array[Byte]^{}, start: Int) extends Mutable:
    private var pos: Int = start
    def peek: Byte = data(pos)
    update def advance(): Unit = pos += 1
  def useReader(d: Array[Byte]^{}): Byte =
    val r = Reader(d, 0)
    r.advance()
    r.peek

  // 3. Frozen arrays in type-argument and tuple positions.
  class Ref[T](var x: T) extends Mutable
  val cell: Ref[Array[Byte]^{}] = Ref(frozen(new Array[Byte](2)))
  val pair: (Int, Array[Long]^{}) = (1, frozen(new Array[Long](1)))
  val opt: Option[Array[Byte]^{}] = Some(frozen(new Array[Byte](1)))

  // 4. An inferred local, stored in a pure field.
  class Keep(parts: List[Int]):
    val y = frozen(parts.toArray)
    val data: Array[Int]^{} = y
