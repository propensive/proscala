package dotty.tools.dotc
package reporting

import core.Contexts.*

/** Bolt codes: the codes by which Propensive's tools name their diagnostics, such
 *  as `↯/p.1.7`. A code is `↯`, and one or more parts each begun by `/`: the
 *  letter of a project (`p` is Proscala) and, after a `.`, a group of numbers,
 *  which are a subdivision of the project, a message in it, and optionally a
 *  variant and a call site.
 *
 *  Proscala's subdivision 1 is upstream's own numbering, so `E007` is
 *  `↯/p.1.7`. A message upstream leaves unnumbered is known by its template —
 *  the constant parts of the `em"..."` string that made it — whose code is
 *  looked up in the registry the build puts beside this class; one given as a
 *  plain string is known by the registry key its text fits. A message from
 *  a macro is `↯/p.2.2`; if the macro began its message with a bolt code of its
 *  own, that code is carried after it, so a macro reporting `[↯/s.87.1.2] ...`
 *  gives `↯/p.2.2/s.87.1.2`.
 */
object BoltCodes:

  /** The group of a message which has no code of its own. */
  final val Unassigned = "2.1"

  /** The group of a message reported by a macro. */
  final val Macro = "2.2"

  /** How a message reported by a macro is known: by the parts of the bolt code
   *  the macro gave it, such as `/s.87.1.2`, or nothing if it gave none.
   */
  final class MacroOrigin(val cause: String)

  def enabled(using Context): Boolean =
    config.Proscala.enabled(config.Proscala.BoltCodes)

  /** The origin of a message that is not a diagnostic at all, such as the count
   *  of errors found, and so has no code.
   */
  object Uncoded

  /** Is this message, at this level, given a code? Errors and warnings are. */
  def applies(level: Int, msg: Message): Boolean =
    level >= interfaces.Diagnostic.WARNING && (msg.boltOrigin ne Uncoded)

  private val Space = "[ \t\r\n\f]+".r

  /** The key of a message's template: its constant parts around `{}`, with each
   *  run of whitespace a single space. `bin/proscala-bolt` computes the same key
   *  from the source.
   */
  def key(template: StringContext): String =
    Space.replaceAllIn(template.parts.mkString("{}"), " ").trim.nn

  /** The registry's codes for unnumbered messages, by key: the build writes
   *  the code and the key of each on a line of `bolt-codes.tsv`.
   */
  private lazy val assigned: Map[String, String] =
    val stream = getClass.getResourceAsStream("bolt-codes.tsv")
    if stream == null then Map.empty
    else
      val source = scala.io.Source.fromInputStream(stream, "UTF-8")
      try
        source.getLines().flatMap: line =>
          line.split("\t", 2) match
            case Array(code, key) if key.nonEmpty => Some(key -> code)
            case _ => None
        .toMap
      finally source.close()

  private val TextKey = "text:"

  /** The keys of messages given as plain strings, as the pattern their text
   *  must fit, with the number of characters it fixes and its code.
   */
  private lazy val texts: List[(java.util.regex.Pattern, Int, String)] =
    import java.util.regex.Pattern
    assigned.toList.collect:
      case (key, code) if key.startsWith(TextKey) =>
        val fixed = key.substring(TextKey.length).nn.split("\\{\\}", -1).map(_.nn)
        (Pattern.compile(fixed.map(Pattern.quote(_)).mkString(".*"), Pattern.DOTALL).nn, fixed.map(_.length).sum, code)

  /** The group of a message which was given as a plain string: that of the key
   *  its text fits, and of the one fixing most of it if it fits several.
   */
  private def ofText(text: String): String =
    val plain = Space.replaceAllIn(text, " ").trim.nn
    assigned.get(TextKey + plain).getOrElse:
      texts.filter(_._1.matcher(plain).nn.matches).maxByOption(_._2).fold(Unassigned)(_._3)

  /** The bolt code of a message. */
  def code(msg: Message): String =
    if msg.errorId != ErrorMessageID.NoExplanationID then s"↯/p.1.${msg.errorId.errorNumber}"
    else msg.boltOrigin match
      case template: StringContext => "↯/p." + assigned.getOrElse(key(template), Unassigned)
      case origin: MacroOrigin => s"↯/p.$Macro${origin.cause}"
      case _ => "↯/p." + ofText(msg.message)

  /** The code a build tool is given for a diagnostic: its bolt code when those
   *  are enabled, and upstream's error number otherwise.
   */
  def diagnosticCode(dia: Diagnostic)(using Context): String =
    if enabled && applies(dia.level, dia.msg) then code(dia.msg) else dia.msg.errorId.errorNumber.toString

  private val Escape = "\u001b\\[[0-9;]*m".r
  private val Group = "[0-9]+(?:\\.[0-9]+)*"
  private val Prefix = s"^\\[?↯((?:/[a-z]\\.$Group)+)\\]?[ ]?".r

  /** The message for text reported by a macro. A bolt code the text begins with,
   *  bracketed or not and coloured or not, is taken out of the text and kept as
   *  the message's origin.
   */
  def fromMacro(text: String)(using Context): Message =
    if !enabled then NoExplanation(text)(using NoContext)
    else
      val plain = Escape.replaceAllIn(text, "")
      Prefix.findPrefixMatchOf(plain) match
        case Some(found) =>
          NoExplanation(drop(text, found.end))(using NoContext)
            .withBoltOrigin(MacroOrigin(found.group(1).nn))
        case _ =>
          NoExplanation(text)(using NoContext).withBoltOrigin(MacroOrigin(""))

  /** `text` without its first `count` characters, not counting colour escapes,
   *  nor the escapes which follow them.
   */
  private def drop(text: String, count: Int): String =
    def escape(index: Int): Int = Escape.findPrefixMatchOf(text.substring(index).nn).fold(0)(_.end)
    var index = 0
    var left = count
    var done = false
    while !done do
      val skip = if index < text.length then escape(index) else 0
      if skip > 0 then index += skip
      else if left > 0 && index < text.length then
        index += 1
        left -= 1
      else done = true
    text.substring(index).nn

end BoltCodes
