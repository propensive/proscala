import defs.*, defs.Series.given

// `xs` is a `Series[Int]` in the body: `total` is not a member of `Seq`.
def total(xs: Int*): Int = xs.total

def describe[T](label: String, xs: T*): String = s"$label has ${xs.count}"

@main def Test =
  println(s"total ${total(1, 2, 3)}; ${describe("letters", 'a', 'b')}; ${total(Seq(4, 5)*)}")
