import scala.language.experimental.captureChecking

trait Board
trait I

given inst: (surface: Board^) => (I^{surface}) = new I {}

def render(canvas: Board^): Unit =
  given canvas0: (Board^{canvas}) = canvas
  summon[I]
