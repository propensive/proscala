// Adapting a read-only reference to an expected type through a base type improved only
// one of `Right`'s two type arguments, and the other was then looked up in the map of
// improvements: a NoSuchElementException in `Mutability.adaptReadOnlyToExpected`.

import caps.*

class Ref extends Mutable:
  private var x: Int = 0
  def get: Int = x
  update def set(y: Int): Unit = x = y

def right(r: Ref^): Either[Int, Ref^{r.rd}] = Right(r)
def left(r: Ref^): Either[Ref^{r.rd}, Int] = Left(r)
def either(r: Ref^, b: Boolean): Either[Int, Ref^{r.rd}] = if b then Right(r) else Left(0)
