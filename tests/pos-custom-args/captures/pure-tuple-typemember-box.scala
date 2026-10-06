import language.experimental.captureChecking
import language.experimental.modularity
import scala.caps

// A tuple of pure elements is itself pure and must not acquire a fresh capture-set variable
// in an invariant (type-member) position. Previously the derived `Showable`'s `text` method
// gained a parameter type `Quanta{ type Form = (Pounds,Stones)^'s1 }` which no longer
// overrode the trait's pure `text(value: Self)`.

class Pounds extends caps.Pure
class Stones extends caps.Pure

trait Showable extends caps.Pure:
  type Self
  def text(value: Self): String

trait Quanta extends caps.Pure:
  type Form

inline given showable: [Q <: Quanta] => Q is Showable = new Showable:
  type Self = Q
  def text(value: Q): String = "x"

extension [L](left: L)
  inline def show(using value: L is Showable): String = value.text(left)

val q: Quanta { type Form = (Pounds, Stones) } = new Quanta { type Form = (Pounds, Stones) }
val s: String = q.show
