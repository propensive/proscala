package lib

object Ordinals:
  opaque type Ordinal = Int

  extension (index: Int) inline def z: Ordinal = index

  extension (ordinal: Ordinal)
    inline def n0: Int = ordinal
    inline infix def till(end: Ordinal): Interval = Interval(ordinal, end)

final class Interval(val start: Int, val end: Int)

extension (interval: Interval)
  inline def each(inline lambda: Ordinals.Ordinal => Unit): Unit =
    import Ordinals.*
    var index = interval.start

    while index < interval.end do
      lambda(index.z)
      index += 1

inline trait Snapshot[operand]:
  import Ordinals.*

  var pos: Int = 0
  var mark: Int = 0
  var count: Int = 0

  private def reconcile(): Unit =
    val end = pos
    (mark.z till end.z).each: index =>
      count += index.n0

  def run(): Unit = reconcile()
