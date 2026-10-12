import scala.scalajs.wit.*

object NonConstant:
  def bytes(module: String, len: unsigned.ULong): Any =
    witImportCall(module, "get-random-bytes",
      classOf[Array[unsigned.UByte]], witList(witPrim("u8")),
      classOf[unsigned.ULong], len)
