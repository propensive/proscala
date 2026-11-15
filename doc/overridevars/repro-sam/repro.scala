import language.experimental.captureChecking

class Point

trait Inspectable:
  type Self
  def text(value: Self): String

inline def derived[value](x: value): Inspectable { type Self = value } = arg => "x"

def test(point: Point) = derived(point)
