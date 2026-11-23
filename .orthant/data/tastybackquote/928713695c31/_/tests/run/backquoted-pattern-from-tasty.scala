// A backquoted identifier in a pattern refers to a stable value. Read back from TASTy,
// which does not record the backquotes, it was taken for a variable pattern and matched
// anything: the first three assertions failed when this test was run from its own TASTy.
// The `_*` of a sequence wildcard is not backquoted, though its name has the same form:
// marked as one, it was compiled as an equality test, and crashed the backend.

object Test:
  def nested(label: String, value: (String, Int)): Int = value match
    case (`label`, number) => number
    case _                 => -1

  def direct(label: String, value: String): Int = value match
    case `label` => 1
    case _       => -1

  def alternative(label: String, other: String, value: String): Int = value match
    case bound @ (`label` | `other`) => 2
    case _                           => -1

  def rest(values: Seq[Int]): Int = values match
    case Seq(first, rest*) => rest.length
    case _                 => -1

  def main(args: Array[String]): Unit =
    assert(nested("a", "z" -> 5) == -1)
    assert(direct("a", "z") == -1)
    assert(alternative("a", "b", "z") == -1)
    assert(nested("a", "a" -> 5) == 5)
    assert(direct("a", "a") == 1)
    assert(alternative("a", "b", "b") == 2)
    assert(rest(Seq(1, 2, 3)) == 2)
    assert(rest(Nil) == -1)
