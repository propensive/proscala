// An inline read from an opaque array whose element type is an alias of the same
// opaque type. The receiver names the opaque type's owner as it is written, so it is
// cast as upstream casts it, and the alias in the element position is left alone:
// following it too would give the read the representation's type, `Array[Byte]`, which
// separation checking does not accept as the `Frozen[Byte]` the caller expects.

package lib

import language.experimental.captureChecking
import language.experimental.separationChecking

opaque type Frozen[element] = Array[element]

object Frozen:
  def apply[element](array: Array[element]): Frozen[element]^{} =
    array.asInstanceOf[Frozen[element]^{}]

  extension [element, C^](buffer: Frozen[element]^{C})
    inline def read(index: Int): element = buffer(index)
