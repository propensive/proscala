import language.experimental.captureChecking
import scala.quoted.*

class Pure

def calcPure[T <: Pure](x: T): Int = 1

inline def goPure[T <: Pure](x: T): Int = ${goPureImpl[T]('x)}

def goPureImpl[T <: Pure](x: Expr[T])(using Type[T], Quotes): Expr[Int] = '{calcPure[T]($x)}
