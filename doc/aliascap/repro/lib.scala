// lib.scala — compiled WITHOUT capture checking (spells its signature
// through the alias)
object Lib:
  def parse(s: String): Int raises ParseError = s.length
