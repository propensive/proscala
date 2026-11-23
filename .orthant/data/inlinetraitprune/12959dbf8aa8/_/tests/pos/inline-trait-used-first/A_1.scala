//> using options -experimental -language:experimental.inlineTraits

// The two files are compiled together, this one first. It only uses the inline trait,
// so its unit has no specializations, and the trait's members were first transformed
// while it was the current unit: they stayed concrete, though the definitions were
// emptied in the trait's own unit. "Concrete method has no definition: def run(): Unit".

package app

object Reader:
  def count(counter: lib.Counter[Byte]): Int =
    counter.advance()
    counter.count
