//> using options -Zalias-captures

class Handle extends caps.ExclusiveCapability:
  def alive: Boolean = true

trait Lender:
  type Result
  def lend[result](lambda: (handle: Result) ?=> result): result

class HandleLender extends Lender:
  type Result = Handle^
  def lend[result](lambda: (handle: Result) ?=> result): result = lambda(using Handle())

given handleLender: HandleLender = HandleLender()

// `lender.Result` is abstract where `lendDef` is defined and an alias of `Handle^` at
// the call: the lambda's parameter is tracked there, and may not escape in the result
extension (x: Int)
  def lendDef[result](using lender: Lender^)(lambda: (handle: lender.Result) ?=> result): result =
    lender.lend(lambda)

def closure(): () => Boolean = 1.lendDef(h ?=> () => h.alive) // error
def pureClosure(): () -> Boolean = 1.lendDef(h ?=> () => h.alive) // error
def handle(): Handle^ = 1.lendDef(h ?=> h) // error
