//> using options -experimental -language:experimental.inlineTraits

// An inline trait with an import in its body, and a class extending it in the same
// run. The import was copied into the class with the trait's other statements, as an
// `Inlined` node whose type is an import type, and Erasure crashed on it:
// "MatchError: ImportType(Ident(Ordinals))".

object Ordinals:
  extension (index: Int) inline def twice: Int = index + index

inline trait Counter[operand]:
  import Ordinals.*

  var count: Int = 1

  def advance(): Unit = count = count.twice

class Doubler extends Counter[Byte]
