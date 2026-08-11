package dotty.tools
package dotc
package util

import scala.collection.mutable

/** Allocation of synthetic output line numbers for inlined code, serialized as a
 *  JSR-45 SMAP (the `SourceDebugExtension` classfile attribute, enabled by `-Xjsr45`).
 *
 *  Line numbers beyond the end of the primary source are allocated per distinct
 *  chain of inline frames. A chain's head is the position the code was written at,
 *  each subsequent frame is the enclosing inline call site, and a complete chain
 *  ends at a position in the primary source. Two strata are emitted:
 *
 *   - `Scala` (the default stratum) maps a synthetic line to the position the
 *     inlined code was written at, which is what JSR-45-aware debuggers use for
 *     breakpoints and stepping;
 *   - `ScalaDebug` maps a synthetic line to its inline call site, with the call
 *     site's line given *in output numbering*. Since real lines are mapped to
 *     themselves, a consumer can follow `ScalaDebug` through nested inlining,
 *     one call site per step, until it reaches a real line of the primary file.
 */
class SmapRegistry(primarySource: SourceFile):
  import SmapRegistry.Frame

  /** 1-based number of the primary source's last line: synthetic lines start above it. */
  private val primaryLastLine: Int = primarySource.offsetToLine(primarySource.length) + 1

  private case class Entry(defFrame: Frame, call: Option[Frame], outputLine: Int)

  private var nextLine: Int = primaryLastLine + 1
  private val entries = mutable.ArrayBuffer.empty[Entry]
  private val memo = mutable.HashMap.empty[List[Frame], Int]

  def isEmpty: Boolean = entries.isEmpty

  /** The synthetic output line for `chain`, allocated on first use. The chain must
   *  be non-empty; its frames hold 1-based line numbers. An incomplete chain (one
   *  that does not end in the primary source) still gets a definition-site mapping,
   *  but the `ScalaDebug` entry that would dangle is omitted.
   */
  def outputLineFor(chain: List[Frame]): Int = memo.get(chain) match
    case Some(line) => line
    case None =>
      val call = chain.tail match
        case (source, line) :: Nil if source == primarySource =>
          Some((source, line)) // a real line, mapped to itself in output numbering
        case Nil => None
        case rest => Some((rest.head._1, outputLineFor(rest)))
      val line = nextLine
      nextLine += 1
      entries += Entry(chain.head, call, line)
      memo(chain) = line
      line

  /** The SMAP text for a class generated from the primary source. */
  def serialize(generatedFileName: String): String =
    val fileIds = mutable.LinkedHashMap[SourceFile, Int](primarySource -> 1)
    def idOf(source: SourceFile): Int = fileIds.getOrElseUpdate(source, fileIds.size + 1)
    for e <- entries do
      idOf(e.defFrame._1)
      for (callSource, _) <- e.call do idOf(callSource)

    val sb = StringBuilder()
    def fileSection(): Unit =
      sb ++= "*F\n"
      for (source, id) <- fileIds do
        sb ++= s"+ $id ${source.name}\n${source.path}\n"

    sb ++= s"SMAP\n$generatedFileName\nScala\n"
    sb ++= "*S Scala\n"
    fileSection()
    sb ++= "*L\n"
    sb ++= s"1#1,$primaryLastLine:1\n"
    var i = 0
    while i < entries.length do
      val e = entries(i)
      val (defSource, defLine) = e.defFrame
      // coalesce runs where input and output lines increase in lockstep
      var n = 1
      while i + n < entries.length
            && entries(i + n).defFrame == (defSource, defLine + n)
            && entries(i + n).outputLine == e.outputLine + n
      do n += 1
      val repeat = if n == 1 then "" else s",$n"
      sb ++= s"$defLine#${idOf(defSource)}$repeat:${e.outputLine}\n"
      i += n

    sb ++= "*S ScalaDebug\n"
    fileSection()
    sb ++= "*L\n"
    for e <- entries do
      for (callSource, callLine) <- e.call do
        sb ++= s"$callLine#${idOf(callSource)}:${e.outputLine}\n"
    sb ++= "*E\n"
    sb.toString
end SmapRegistry

object SmapRegistry:
  /** A source position in an inline chain: source file and 1-based line number.
   *  In a chain's head the line is a source line; in `Entry.call` it is a line in
   *  output numbering (real lines are their own output lines, nested call sites
   *  are synthetic).
   */
  type Frame = (SourceFile, Int)
