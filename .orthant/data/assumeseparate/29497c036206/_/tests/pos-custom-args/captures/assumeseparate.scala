// `unsafeAssumeSeparate` returns its operand as it is: an exclusive capability stays
// exclusive, so it can still be returned or passed where one is required.
import language.experimental.separationChecking

trait Sink extends caps.ExclusiveCapability, caps.Stateful:
  update def put(i: Int): Unit

def pass(consume sink: Sink^): Sink^ = scala.caps.unsafe.unsafeAssumeSeparate(sink)
def cast(consume sink: Sink^): Sink^ = scala.caps.unsafe.unsafeAssumeSeparate(sink.asInstanceOf[Sink^])
