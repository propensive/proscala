// A parenthesized type with a capture set, as the parameter of a function type. The
// types within the parentheses were counted as parameters of a function, and the
// whole type then counted again as the one parameter it is.

trait A
trait B

def context[T](block: (A & B)^ ?=> T): T = ???
def impure[T](block: (A & B)^ => T): T = ???
def pure[T](block: (A & B)^ -> T): T = ???
type F[T] = (A & B)^ ?=> T
type G[T] = ((A & B)^) ?=> T
