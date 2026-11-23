// A default argument in a clause before an interleaved type-parameter clause, in an
// application that is lifted into a block: the type arguments have to be applied to
// the block's expression, not to the block.

trait TC
given tc0: TC = new TC {}

def f(using tc: TC)(flags: List[String] = Nil)[C](g: Int => C): C = g(0)
def h(tc: TC)(flags: List[String] = Nil)[C](g: Int => C): C = g(0)

val viaUsing = f()(identity)
val viaImpure = h(new TC {})()(identity)
