import caps.*

class Buffer extends Mutable:
  update def write(b: Byte): Unit = ()

trait Maker:
  def make(): Buffer^        // result capability is an existential ResultCap

val maker: Maker = () => Buffer()   // SAM literal
