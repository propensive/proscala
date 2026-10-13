import language.experimental.captureChecking
import language.experimental.separationChecking

trait Sink extends caps.ExclusiveCapability, caps.Stateful:
  update def put(i: Int): Unit

def sinks(): IndexedSeq[Sink^] = IndexedSeq()

def drain(consume sink: Sink^): Unit = sink.put(0)

def write(): Unit =
  val all = sinks()
  val second = scala.caps.unsafe.unsafeAssumeSeparate(all(1))
  drain(second)
