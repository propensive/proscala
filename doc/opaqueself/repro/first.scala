import lib.*

// `boxed` is the first member of `lib.Array` this run looks at.
def first(xs: Array[Int]^{}): Box[Array[Int]^{}] =
  Array.boxed(xs)
