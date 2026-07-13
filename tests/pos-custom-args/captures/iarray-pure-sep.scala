import language.experimental.captureChecking
import language.experimental.separationChecking

// Under separation checking (strict mutability), IArray purity must also hold through
// the type-level `isArrayUnderStrictMut` test: previously the classification dealiased
// straight to `Array`, bypassing the IArray exemption, and every stdlib factory or
// combinator result was freshened (`IArray[Byte]^{any}` against the pure alias).
object SepTest:
  type Data = IArray[Byte]

  trait Addressable:
    val empty: Data

  inline given bytes: Addressable = new Addressable:
    val empty: Data = IArray.from(Nil)

  def grab(bytes: Data): Data = bytes.slice(0, 1)
