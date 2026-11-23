//> using options -experimental -language:experimental.inlineTraits

package app

class Parser extends lib.Snapshot[Byte]

object Reader:
  // reads `Parser` back from its TASTy when the two files are compiled together
  def count(parser: Parser): Int =
    parser.run()
    parser.count
