package app

object Use:
  def nested(label: String, value: (String, Int)): Int = value match
    case (`label`, number) => number
    case _                 => -1

  def direct(label: String, value: String): Int = value match
    case `label` => 1
    case _       => -1

  def main(args: Array[String]): Unit =
    println(s"${nested("a", "z" -> 5)} ${direct("a", "z")}")
