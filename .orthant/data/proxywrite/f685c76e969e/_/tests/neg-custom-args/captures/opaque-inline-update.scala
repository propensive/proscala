import scala.language.experimental.captureChecking
import scala.language.experimental.separationChecking

object p:
  object Arr:
    def allocate[element](size: Int): Arr[element]^ =
      new scala.Array[AnyRef](size).asInstanceOf[scala.Array[element]]

    extension [element](inline buffer: Arr[element]^)
      inline def update(index: Int, value: element): Unit = buffer(index) = value

    extension [element](inline buffer: Arr[element]^{})
      inline def put(index: Int, value: element): Unit = buffer(index) = value

  opaque type Arr[element] = scala.Array[element]

def test(): Unit =
  val arr: p.Arr[String]^ = p.Arr.allocate[String](3)
  arr(1) = ""
  val frozen: p.Arr[String]^{} = caps.unsafe.unsafeAssumePure(arr)
  frozen.put(1, "") // error
  frozen(1) = "" // error
