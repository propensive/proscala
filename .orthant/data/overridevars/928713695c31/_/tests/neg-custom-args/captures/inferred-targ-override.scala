// The capture set variables unified for an override are still checked: a method that needs
// its parameter to be pure cannot implement one that is passed a capability.

class Point

trait Member:
  type Self
  def text(value: Self): String

def pure(point: Point): String = "x"

inline def member[value <: Point](x: value): Member { type Self = value } =
  new Member:
    type Self = value
    def text(arg: value): String = pure(arg)

def ok(point: Point) = member(point).text(point)

def test(point: Point, io: Point^) = member(point).text(io) // error
