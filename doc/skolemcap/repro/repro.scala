import language.experimental.captureChecking
import compiletime.summonInline

trait Tactic extends caps.SharedCapability

// A given *method*: the tactic it supplies is an application, not a stable path.
given tactic: () => Tactic = ???

trait Decodable

// The result's capture set retains the parameter.
given decodable: (tactic: Tactic) => (Decodable^{tactic}) = ???

def decode(using decodable: Decodable^): Unit = ()

// Soundness's `provide`: resolve the context with `summonInline` and pass it to an
// inline context-function argument.
inline def provide[context](inline body: context ?=> Unit): Unit =
  body(using summonInline[context])

def run(): Unit = provide[Decodable](decode)
