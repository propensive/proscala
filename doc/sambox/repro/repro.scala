import caps.*

class Handle extends ExclusiveCapability   // a capability type

trait Source:
  type Self
  def stream(value: Self): Unit            // the single abstract method

val s: Source { type Self = Handle^ } = handle => ()
