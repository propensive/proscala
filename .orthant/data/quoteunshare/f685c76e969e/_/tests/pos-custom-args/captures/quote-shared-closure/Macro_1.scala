import scala.quoted.*

class Tactic extends caps.Control

def safely[result](block: (tactic: Tactic^) ?=> result): result = block(using Tactic())
def compute(value: Int)(using Tactic): Int = value

inline def serve(value: Int): Int = ${Macros.serve('value)}

object Macros:
  // The closure the compiler makes for `safely`'s argument has a parameter whose type
  // tree names nothing of the quote: the copies made of the cached quote share it.
  def serve(value: Expr[Int])(using Quotes): Expr[Int] = '{safely(compute($value))}
