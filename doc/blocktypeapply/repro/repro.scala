trait TC
given tc0: TC = new TC {}

def f(using tc: TC)(flags: List[String] = Nil)[C](g: Int => C): C = g(0)

val r = f()(identity)
