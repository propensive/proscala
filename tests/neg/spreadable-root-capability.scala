import scala.language.experimental.{captureChecking, spreadable}
object Handlers:
  given (Spreadable[Handlers] { type Out = Vector[() => Unit] }) =
    new Spreadable[Handlers]:
      type Out = Vector[() => Unit]
      def spread(value: Handlers): Vector[() => Unit] = value
opaque type Handlers = Vector[() => Unit]
object Use:
  def count(hs: (() => Unit)*): Int = hs.length
  def a(h: Handlers) = count(h*)
