class Box[T](val value: T)

object Test:
  def run(): Unit =
    val b2: Box[String] = Box("x")
    val b3: Box[Int] = b2
