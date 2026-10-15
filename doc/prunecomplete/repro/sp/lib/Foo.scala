package lib
import scala.annotation.compileTimeOnly
class Foo[T](x: T)(implicit num: Integral[T])
object Foo:
  class Inclusive[T](x: T)(implicit num: Integral[T]) extends Foo(x)
