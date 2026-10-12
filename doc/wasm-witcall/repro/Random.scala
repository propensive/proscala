import scala.scalajs.wit.*

object Random:
  def bytes(len: unsigned.ULong): Array[unsigned.UByte] =
    witImportCall("wasi:random/random@0.2.0", "get-random-bytes",
      classOf[Array[unsigned.UByte]], witList(witPrim("u8")),
      classOf[unsigned.ULong], len
    ).asInstanceOf[Array[unsigned.UByte]]
