import language.experimental.captureChecking
import scala.caps

trait Tactic extends caps.ExclusiveCapability
class Err()

def abort(error: Err)(using tactic: Tactic^): Nothing = throw Exception()

class Parser():
  private inline def expect(count: Int): Tactic^ ?=> Unit =
    ()

  private inline def inner(): Tactic^ ?=> Int =
    expect(2)
    42

  private inline def outer(length: Long): Tactic^ ?=> Int =
    expect(length.toInt)
    length.toInt

  def test()(using Tactic^): Int =
    outer(inner())
