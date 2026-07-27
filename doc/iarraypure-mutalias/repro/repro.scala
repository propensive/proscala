// Compile with: -experimental -Ycc-new -language:experimental.captureChecking
//
// Unpatched: compiles silently -- the write through the read-only parameter
// is not detected, because the opaque alias hides `Array`'s mutability
// classification outside its defining scope.
//
// Patched: one error at the marked line:
//   Found:    (buffer : repro.Buffer[Int])
//   Required: repro.Buffer[Int]^{any}
package repro

import scala.reflect.ClassTag

object Buffer:
  def make[element: ClassTag](size: Int): Buffer[element]^ =
    new Array[element](size)

  extension [element](buffer: Buffer[element]^)
    def place(index: Int, value: element): Unit = buffer(index) = value

opaque type Buffer[element] = Array[element]

object Test:
  def sneaky(buffer: Buffer[Int]): Unit = buffer.place(0, 99)  // EXPECT ERROR when patched
