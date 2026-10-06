package dotty.tools
package dotc
package util

import scala.collection.mutable

/** Allocation of synthetic output line numbers for inlined code, serialized as a
 *  JSR-45 SMAP (the `SourceDebugExtension` classfile attribute, enabled by `-Zinline-source-maps`).
 *
 *  Line numbers beyond the end of the primary source are allocated per distinct
 *  chain of inline frames. A chain's head is the position the code was written at,
 *  each subsequent frame is the enclosing inline call site, and a complete chain
 *  ends at a position in the primary source. Three strata are emitted:
 *
 *   - `Scala` (the default stratum) maps a synthetic line to the position the
 *     inlined code was written at, which is what JSR-45-aware debuggers use for
 *     breakpoints and stepping;
 *   - `ScalaDebug` maps a synthetic line to its inline call site, with the call
 *     site's line given *in output numbering*. Since real lines are mapped to
 *     themselves, a consumer can follow `ScalaDebug` through nested inlining,
 *     one call site per step, until it reaches a real line of the primary file;
 *   - `ScalaClass` maps a synthetic line to the binary name of the top-level
 *     class whose compilation unit the inlined code was written in (the stratum's
 *     "files" are class names, and its input lines are always 1). This is what
 *     lets tooling find the class's TASTy — and with it the inline method's
 *     definition — without guessing, since a source position alone names no class.
 */
class SmapRegistry(primarySource: SourceFile):
  import SmapRegistry.Frame

  /** 1-based number of the primary source's last line: synthetic lines start above it. */
  private val primaryLastLine: Int = primarySource.offsetToLine(primarySource.length) + 1

  private case class Entry(defFrame: Frame, call: Option[Frame], outputLine: Int)

  private var nextLine: Int = primaryLastLine + 1
  private val entries = mutable.ArrayBuffer.empty[Entry]
  private val memo = mutable.HashMap.empty[List[Frame], Int]

  /** The synthetic output line for `chain`, allocated on first use. The chain must
   *  be non-empty; its frames hold 1-based line numbers. An incomplete chain (one
   *  that does not end in the primary source) still gets a definition-site mapping,
   *  but the `ScalaDebug` entry that would dangle is omitted.
   */
  def outputLineFor(chain: List[Frame]): Int = memo.get(chain) match
    case Some(line) => line
    case None =>
      val call = chain.tail match
        case Frame(source, line, _) :: Nil if source == primarySource =>
          Some(Frame(source, line, "")) // a real line, mapped to itself in output numbering
        case Nil => None
        case rest => Some(Frame(rest.head.source, outputLineFor(rest), ""))
      val line = nextLine
      nextLine += 1
      entries += Entry(chain.head, call, line)
      memo(chain) = line
      line

  /** The SMAP text describing exactly `usedLines` — the synthetic lines that one
   *  generated class emitted — or the empty string if none of them is a synthetic line
   *  of this unit. A unit's registry covers every inlined line in the unit, which for a
   *  unit that inlines heavily is far more than any one of its classes uses.
   *
   *  A line's call site may itself be a synthetic line the class never emitted (the
   *  inner call of a nested expansion), so the entries are closed over the `ScalaDebug`
   *  chain: without that, following the chain would dead-end part-way out.
   */
  def serialize(generatedFileName: String, usedLines: collection.Set[Int]): String =
    val byOutputLine = entries.iterator.map(e => e.outputLine -> e).toMap

    val included = mutable.TreeSet.empty[Int]

    // Walked with an explicit worklist rather than by recursion: a unit that inlines
    // deeply produces a correspondingly long `call` chain, and recursing it costs
    // several stack frames per link, which overflows the stack on the heaviest units.
    def include(start: Int): Unit =
      var pending = start :: Nil
      while pending.nonEmpty do
        val line = pending.head
        pending = pending.tail
        if !included.contains(line) then
          byOutputLine.get(line) match
            case None => ()
            case Some(e) =>
              included += line
              e.call match
                case Some(call) if call.line > primaryLastLine => pending = call.line :: pending
                case _ => ()

    usedLines.foreach(include)

    if included.isEmpty then "" else
      val chosen = included.toArray.map(byOutputLine)

      val fileIds = mutable.LinkedHashMap[SourceFile, Int](primarySource -> 1)
      def idOf(source: SourceFile): Int = fileIds.getOrElseUpdate(source, fileIds.size + 1)
      for e <- chosen do
        idOf(e.defFrame.source)
        for call <- e.call do idOf(call.source)

      val classIds = mutable.LinkedHashMap[String, Int]()
      for e <- chosen if e.defFrame.cls.nonEmpty do
        classIds.getOrElseUpdate(e.defFrame.cls, classIds.size + 1)

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
      while i < chosen.length do
        val e = chosen(i)
        val Frame(defSource, defLine, defCls) = e.defFrame
        // coalesce runs where input and output lines increase in lockstep
        var n = 1
        while i + n < chosen.length
              && chosen(i + n).defFrame == Frame(defSource, defLine + n, defCls)
              && chosen(i + n).outputLine == e.outputLine + n
        do n += 1
        val repeat = if n == 1 then "" else s",$n"
        sb ++= s"$defLine#${idOf(defSource)}$repeat:${e.outputLine}\n"
        i += n

      sb ++= "*S ScalaDebug\n"
      fileSection()
      sb ++= "*L\n"
      for e <- chosen do
        for call <- e.call do
          sb ++= s"${call.line}#${idOf(call.source)}:${e.outputLine}\n"

      if classIds.nonEmpty then
        sb ++= "*S ScalaClass\n"
        sb ++= "*F\n"
        for (cls, id) <- classIds do sb ++= s"$id $cls\n"
        sb ++= "*L\n"
        for e <- chosen do
          if e.defFrame.cls.nonEmpty then
            sb ++= s"1#${classIds(e.defFrame.cls)}:${e.outputLine}\n"

      sb ++= "*E\n"
      sb.toString
end SmapRegistry

object SmapRegistry:
  /** A source position in an inline chain: source file, 1-based line number, and
   *  the binary name of the top-level class whose compilation unit the position
   *  lies in — empty when unknown, as it is for call sites in the primary source,
   *  which need no class (the classfile itself provides that context). In a
   *  chain's head the line is a source line; in `Entry.call` it is a line in
   *  output numbering (real lines are their own output lines, nested call sites
   *  are synthetic).
   */
  case class Frame(source: SourceFile, line: Int, cls: String)
