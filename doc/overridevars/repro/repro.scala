import language.experimental.captureChecking

class Point

trait Inspectable:
  type Self
  def text(value: Self): String

inline def derived[value](x: value): Inspectable { type Self = value } =
  new Inspectable:
    type Self = value
    def text(arg: value): String = "x"

def test(point: Point) = derived(point)
