import scala.quoted.*

class Tactic extends caps.SharedCapability

trait Postable:
  def stream(payload: String): String

object Postable:
  given dataStream: (tactic: Tactic) => (Postable^{tactic}) = ???

trait Spring:
  def apply(): String

class Request(val spring: Spring)

inline def submit(payload: String)(using postable: Postable^): Request =
  ${Macros.submit('payload, 'postable)}

object Macros:
  // Typer ascribes the anonymous class instance below with `Spring`. A quote is
  // unpickled once, so each expansion of `submit` in a unit has the same tree for
  // that ascription.
  def submit(payload: Expr[String], postable: Expr[Postable])(using Quotes): Expr[Request] =
    ' {
        given postable0: Postable = caps.unsafe.unsafeAssumePure($postable)

        val request =
          new Request
            ( caps.unsafe.unsafeAssumePure:
                new Spring:
                  def apply(): String = postable0.stream($payload) )

        request
      }
