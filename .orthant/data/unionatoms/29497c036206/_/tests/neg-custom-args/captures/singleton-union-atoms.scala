// Atoms still tell singletons apart under capture checking.

class Kind

object N:
  val k1 = Kind()
  val k2 = Kind()
  val k3 = Kind()
  val e: k3.type = k3
  val f: k1.type | k2.type = e  // error
  val g: k1.type | k2.type = k3 // error
