import language.experimental.captureChecking

class Kind

object P:
  val k1 = Kind()
  val k2 = Kind()
  val e: k1.type = k1
  val f: k1.type | k2.type = e
