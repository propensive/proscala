class Handle extends caps.ExclusiveCapability:
  def alive: Boolean = true

trait Lender:
  type Result
  def lend[result](lambda: (handle: Result) ?=> result): result

class HandleLender extends Lender:
  type Result = Handle^
  def lend[result](lambda: (handle: Result) ?=> result): result = lambda(using Handle())

given handleLender: HandleLender = HandleLender()

// The closure's parameter has an abstract type member's type, which at the call site
// aliases `Handle^`: its proxy must keep it declared, so that the closure tracks it
extension (x: Int)
  transparent inline def lendInline[result](using lender: Lender^)(lambda: (handle: lender.Result) ?=> result): result =
    lender.lend(lambda)
