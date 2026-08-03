import scala.language.experimental.{spreadable, captureChecking}

// covariant opaque alias over IArray — the shape that crashed the capture
// checker before the wildcard-array fix, and that needs castbox on 3.10
object Nodes:
  def apply(ns: String*): Nodes = IArray(ns*)
  given (Spreadable[Nodes] { type Out = IArray[String] }) =
    new Spreadable[Nodes]:
      type Out = IArray[String]
      def spread(value: Nodes): IArray[String] = value
opaque type Nodes = IArray[String]

object Series:
  def apply(es: Int*): Series = es.toVector
  given (Spreadable[Series] { type Out = Vector[Int] }) =
    new Spreadable[Series]:
      type Out = Vector[Int]
      def spread(value: Series): Vector[Int] = value
opaque type Series = Vector[Int]

object Use:
  def join(ns: String*): String = ns.mkString(",")
  def sum(xs: Int*): Int = xs.sum
  def a = join(Nodes("x","y")*)     // IArray-flavoured alias under -Ycc-new
  def b = sum(Series(1,2)*)         // Seq-flavoured alias under -Ycc-new
