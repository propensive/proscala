package defs

// A collection that is not a `Seq`: an opaque alias, with its own API.
object Series:
  extension [e](series: Series[e])
    def total(using numeric: Numeric[e]): e = series.sum
    def count: Int = series.length

  // Repeated parameters are received as a `Series` wherever this is in scope.
  given [e] => (Gatherable[e] { type Out = Series[e] }) =
    new Gatherable[e]:
      type Out = Series[e]
      def gather(elements: Seq[e]): Series[e] = elements.toVector

opaque type Series[+e] = Vector[e]
