import language.experimental.captureChecking

class CT[-E <: Exception] extends caps.ExclusiveCapability

def Throw[Ex <: Exception](ex: Ex)(using CT[Ex]^): Nothing = ???

class Ex2 extends Exception; class Ex3 extends Exception

// error: the body uses x$1 (bound by the OUTER ?=> layer)
// from inside the INNER ?=> layer
def foo9a(i: Int): (x$1: CT[Ex3]^) ?=> (x$2: CT[Ex2]^) ?=> Unit =
  (x$1: CT[Ex3]^) ?=> (x$2: CT[Ex2]^) ?=> Throw(new Ex3)
