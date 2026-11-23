//> using options -Zfrozen-pure -Zopaque-mutability
import language.experimental.captureChecking
import caps.*

// `-Zfrozen-pure` makes a frozen array pure for classification, but never writable: the
// exclusivity check still looks through the empty set, so every write below is rejected.
object FrozenWrite:
  opaque type Buf = Array[Int]^{}
  def write1(a: Array[Int]^{}): Unit = a(0) = 1        // error
  def write2(b: Buf): Unit = b(0) = 1                   // error
  def widen(a: Array[Int]^{}): Unit =
    val c: Array[Int]^ = a                              // error
    c(0) = 1
  class Cell extends Mutable:
    var x: Int = 0
    update def set(v: Int): Unit = x = v
  def write3(c: Cell^{}): Unit = c.set(1)               // error
