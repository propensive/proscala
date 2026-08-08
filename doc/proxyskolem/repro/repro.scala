import scala.language.experimental.captureChecking
import scala.compiletime.asMatchable

trait Decodable:
  type Self
  def decode(s: String): Self

object Deriver:
  inline def conjunction[T <: Product]: (Decodable { type Self = T })^ =
    new Decodable:
      type Self = T
      def decode(s: String): T = ???

  inline def derivedOne[T]: Decodable { type Self = T } =
    conjunction[T & Product].asMatchable match
      case typeclass: (Decodable { type Self = T }) => typeclass

case class Layout(version: String)

def test: Decodable { type Self = Layout } = Deriver.derivedOne[Layout]
