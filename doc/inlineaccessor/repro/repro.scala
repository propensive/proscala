import scala.language.experimental.captureChecking
import scala.language.experimental.separationChecking
import scala.language.experimental.inlineTraits

object Cursor:
  inline trait Snapshot[operand] extends caps.Stateful:
    @caps.unsafe.untrackedCaptures
    protected var cells: scala.Array[operand] = null.asInstanceOf[scala.Array[operand]]
    protected var pos: Int = 0
    protected inline def peek: operand = cells(pos)

class Parser extends caps.Mutable, Cursor.Snapshot[Byte]:
  private var count = 0
  update def step(): Byte =
    count += 1
    peek
