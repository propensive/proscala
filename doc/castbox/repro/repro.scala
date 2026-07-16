import language.experimental.captureChecking
import scala.caps

object internal:
  opaque type Tagged[+value, tag] = value
  object Tagged:
    inline def apply[tag](value: Any): Tagged[value.type, tag] = value

trait Tactic extends caps.ExclusiveCapability

def demo(using t: Tactic): Unit =
  val inst: Object^{t} = new Object {}
  internal.Tagged["label"](inst)   // inlined: inst.asInstanceOf[Tagged[inst.type, "label"]]
  // error: Tagged[box (inst : Object^{t}), "label"] expected,
  //        but the cast produced the unboxed spelling
