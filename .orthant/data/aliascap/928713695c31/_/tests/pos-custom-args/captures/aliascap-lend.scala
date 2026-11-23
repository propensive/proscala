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

// A lambda using what it is lent, without letting it escape
extension (x: Int)
  def lendDef[result](using lender: Lender^)(lambda: (handle: lender.Result) ?=> result): result =
    lender.lend(lambda)

  def lendDefHat[result](using lender: Lender^)(lambda: (handle: lender.Result^) ?=> result): result =
    lender.lend(lambda)

def use(): Boolean = 1.lendDef(h ?=> h.alive == true)
def useHat(): Boolean = 1.lendDefHat(h ?=> h.alive == true)
