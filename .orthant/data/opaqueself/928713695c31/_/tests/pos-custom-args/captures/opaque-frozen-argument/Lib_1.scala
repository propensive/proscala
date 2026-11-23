// A frozen opaque array in a type argument of a result type, in a signature read from
// TASTy. Using `size` first makes the capture checker look at `Array` inside its scope
// after Setup has transformed the class which holds it; `boxed`'s result must still be
// read as `Box[Array[E]^{}]`, not as `Box[scala.Array[E]^{any.rd}]`.

package lib

import language.experimental.captureChecking
import language.experimental.separationChecking

class Box[+T](val value: T)

object Array:
  def size[E](xs: Array[E]^{}): Int = xs.length
  def boxed[E](xs: Array[E]^{}): Box[Array[E]^{}] = Box(xs)

object Bytes:
  def size(xs: Bytes^{}): Int = xs.length
  def boxed(xs: Bytes^{}): Box[Bytes^{}] = Box(xs)

opaque type Array[E] = scala.Array[E]
opaque type Bytes = scala.Array[Byte]
