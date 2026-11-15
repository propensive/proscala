package app

class Box(val label: String):
  given alias: String = label

object Show:
  def main(args: Array[String]): Unit =
    val cached = classOf[Box].getDeclaredFields.exists(_.getName.startsWith("alias$lzy"))
    println(if cached then "cached" else "uncached")
