import language.experimental.captureChecking
import language.experimental.separationChecking

trait Sink extends caps.ExclusiveCapability, caps.Stateful:
  update def put(i: Int): Unit

def pass(consume sink: Sink^): Sink^ = scala.caps.unsafe.unsafeAssumeSeparate(sink)
