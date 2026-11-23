import language.experimental.captureChecking
import language.experimental.modularity
import scala.caps

// A value of a *pure* type must not acquire a capture set when it flows out of an inline
// given of a `Self`-typeclass instantiated at that pure type, via an inline extension.
// Previously this produced: "Text is a pure type, it makes no sense to add a capture set to it".

opaque type Text <: Matchable & caps.Pure = String & caps.Pure
object Text:
  def apply(s: String): Text = s.asInstanceOf[Text]

trait Decomposable extends caps.Pure:
  type Self
  def decomposition(value: Self): Text

inline given derived: [entity] => entity is Decomposable = new Decomposable:
  type Self = entity
  def decomposition(value: entity): Text = Text("x")

extension [left](left: left)
  inline def decompose(using value: left is Decomposable): Text = value.decomposition(left)

val d: Text = Text("hello").decompose
