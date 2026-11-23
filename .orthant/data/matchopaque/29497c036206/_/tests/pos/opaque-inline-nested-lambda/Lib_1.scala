// An inline method beside an opaque type, taking a lambda over that type, and called
// from another inline method: the second call's argument has the lambda's type as the
// first call left it, naming the opaque type through that call's proxy, where it is an
// alias of its representation. Following that alias cast the lambda to a function of
// the representation, which the opaque value it is applied to is not.

package lib

opaque type Scribe[element] = Scribe.Core

object Scribe:
  final class Core(val buffer: AnyRef)

  def apply[element](buffer: AnyRef): Scribe[element] = new Core(buffer)

  inline def over[element, result](buffer: AnyRef)
    ( inline lambda: (scribe: Scribe[element]) => Int => result )
  :   result =

    val scribe = Scribe[element](buffer)
    lambda(scribe)(0)

extension (companion: Array.type)
  inline def scribe[element](size: Int)
    ( inline lambda: (scribe: Scribe[element]) => Int => Unit )
  :   Unit =

    Scribe.over[element, Unit](new Object)(lambda)
