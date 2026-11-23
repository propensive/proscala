import language.experimental.separationChecking
import language.experimental.captureChecking
import language.experimental.separationChecking
import scala.caps

trait Tactic extends caps.SharedCapability
class Throwing[E] extends Tactic
given throwing: [E] => (Throwing[E]^) = Throwing()

class Sink extends caps.Unscoped
inline given sink: (Sink^) = Sink()

class Holder(val tactic: Tactic, val sink: Sink^)

given holder: (tactic: Tactic, sink: Sink^) => (Holder^{tactic, sink, caps.any}) = Holder(tactic, sink)

def use(): Int =
  val h = summon[Holder^]
  1
