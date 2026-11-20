import lib.*

// The same call, after another member of `lib.Array` has been used.
def client(xs: Array[Int]^{}): Box[Array[Int]^{}] =
  val size = Array.size(xs)
  Array.boxed(xs)
