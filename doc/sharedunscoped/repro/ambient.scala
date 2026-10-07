import language.experimental.captureChecking
import scala.caps

trait Tactic[E] extends caps.SharedCapability:
  def abort(error: E): Nothing

class Throwing[E] extends Tactic[E], caps.SharedUnscoped:
  def abort(error: E): Nothing = throw new RuntimeException(error.toString)

given throwing: [E] => (Throwing[E]^) = Throwing()

trait Decodable[T]:
  def decoded(input: String): T

given intCodec: (tactic: Tactic[String]) => (Decodable[Int]^{tactic}) = new Decodable[Int]:
  def decoded(input: String): Int =
    if input.isEmpty then tactic.abort("empty") else input.length

// The by-name element codec, as jacinta's `optional`/`array`/`map` givens take it.
// Sealed pure as jacinta's `optional` is (a by-name parameter cannot be named in a capture
// set — safety-10); the level check on the synthesised thunk happens before the seal.
given optionCodec: [T] => (inner: => Decodable[T]^) => Decodable[Option[T]] =
  caps.unsafe.unsafeAssumePure:
    new Decodable[Option[T]]:
      def decoded(input: String): Option[T] =
        if input == "null" then None else Some(inner.decoded(input))

def use(): Option[Int] = summon[Decodable[Option[Int]]].decoded("abc")
