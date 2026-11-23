//> using options -experimental -language:experimental.inlineTraits

package lib

inline trait Counter[operand]:
  var count: Int = 1

  def advance(): Unit = count = count + count
