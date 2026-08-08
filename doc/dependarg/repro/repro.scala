trait Multiplicable:
  type Self
  type Operand
  type Result
type IsM2 = Multiplicable { type Self = Int }
infix type by[refined <: { type Operand }, operand] = refined { type Operand = operand }
def f(using multiplicable: IsM2 by Int, equality: multiplicable.Result =:= Int): Int = ???
def g(using multiplicable: IsM2 by Int, equality: multiplicable.Result =:= Int): Int = f(using multiplicable, equality)
