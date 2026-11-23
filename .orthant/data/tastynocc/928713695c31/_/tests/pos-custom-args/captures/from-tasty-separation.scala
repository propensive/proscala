import language.experimental.captureChecking
import language.experimental.separationChecking

// Compiles, but did not recompile from its TASTy with the same options: TASTy does not
// record that the type of `boxed` was inferred, so the checker read `Array[AnyRef]` as
// written, a read-only array ("Cannot call update method"), and it took the enum's
// synthesized members the same way. A run which reads its units from TASTy no longer
// checks captures.

enum State:
  case Active, Stopped

object Sorting:
  def boxed(raw: Array[Int]): Int =
    val boxed = new Array[AnyRef](raw.length)
    var index = 0

    while index < raw.length do
      boxed(index) = raw(index).asInstanceOf[AnyRef]
      index += 1

    boxed.length
