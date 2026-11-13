package client

import lib.*

// `use.Aliased` is compiled separately, so the type of its `ref` is read here
// from TASTy: `Cell[String]`, as declared.
@main def Client(): Unit =
  val first = use.Aliased.ref()
  val swapped = use.Aliased.ref.swap("b")
  println(s"$first $swapped ${use.Aliased.ref()}")
