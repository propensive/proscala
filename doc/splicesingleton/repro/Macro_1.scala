import language.experimental.captureChecking
import scala.quoted.*

class Path

def calc[T <: Path^](x: T): Int = 1

inline def go[T <: Path^](x: T): Int = ${goImpl[T]('x)}

def goImpl[T <: Path^](x: Expr[T])(using Type[T], Quotes): Expr[Int] = '{calc[T]($x)}
