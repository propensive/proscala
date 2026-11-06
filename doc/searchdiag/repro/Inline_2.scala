//> using options -Zdiagnostic-givens

import Givens.given

trait Shape:
  def name: String

object Shape:
  given square: Shape = new Shape { def name = "square" }

// The search for `Shape` runs while the inline body is typed, where no inline
// call is expanded: the catch-all, found first in lexical scope, must not be
// accepted unexpanded ahead of the companion's instance.
inline def shape: Shape = summon[Shape]

def shapeName: String = shape.name
