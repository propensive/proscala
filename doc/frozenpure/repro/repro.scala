import language.experimental.captureChecking
import language.experimental.separationChecking
import scala.caps

// Stand-in for proscenium.Array: an opaque alias over the mutable array, pierced by mutalias.
object arrays:
  opaque type A[e] = scala.Array[e]
  object A:
    def allocate(n: Int): A[Int]^ = new scala.Array[Int](n)
    def freeze[e](consume a: A[e]^): A[e]^{} = caps.unsafe.unsafeAssumePure(a)
    extension [e, C^](a: A[e]^{C}) inline def length: Int = a.length
    extension [e, C^](a: A[e]^{C}) inline def readUnchecked(i: Int): e = a(i)
    extension [e](inline a: A[e]^) inline def update(i: Int, v: e): Unit = a(i) = v

import arrays.*

// R1: an opaque alias over the frozen form, with a field typed by it in the defining scope.
object decimal:
  opaque type D = A[Int]^{}
  object D:
    val zero: D = A.freeze(A.allocate(2))
    def apply(n: Int): D = A.freeze(A.allocate(n))
    extension (d: D) def digits: Int = d.length
    class Holder(d: D):
      val stored: D = d
      val back: D = zero
