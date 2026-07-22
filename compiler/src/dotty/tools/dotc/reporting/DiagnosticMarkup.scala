package dotty.tools
package dotc
package reporting

import scala.collection.mutable

import core.Contexts.*
import util.Property

/** In-band markup for semantic diagnostics, enabled by `-Xsemantic-diagnostics`.
 *
 *  While a `Message` is forced under the flag, the `i`/`em` string interpolators
 *  wrap the shown form of each interpolated argument in markers from the Unicode
 *  private use area, recording what kind of entity produced the text (a type, a
 *  symbol, a name, a tree) together with attributes such as the TASTy
 *  serialization of a type. `XmlReporter` parses the markers back into structure;
 *  every other consumer sees them stripped by `plain`.
 *
 *  A marker has the form
 *
 *      Start kind AttrsSep key=value (AttrSep key=value)* TextSep text End
 *
 *  where the marked text never itself contains markers. Attribute values are
 *  percent-encoded (`%hhhh`, four hex digits) so that they cannot contain the
 *  marker characters or the attribute separator.
 */
object DiagnosticMarkup:

  /** Present on the context while a message is forced with markup enabled. */
  val Active: Property.Key[Unit] = new Property.Key

  def active(using Context): Boolean = ctx.property(Active).isDefined

  private final val Start    = '\uE000'
  private final val End      = '\uE001'
  private final val AttrsSep = '\uE002'
  private final val TextSep  = '\uE003'
  private final val AttrSep  = '\u001F'

  private def isReserved(c: Char): Boolean =
    c == '%' || (c >= Start && c <= TextSep) || c < ' '

  private def encode(s: String): String =
    if !s.exists(isReserved) then s
    else
      val b = new StringBuilder
      for c <- s do
        if isReserved(c) then b.append(f"%%${c.toInt}%04x") else b.append(c)
      b.toString

  private def decode(s: String): String =
    if !s.contains('%') then s
    else
      val b = new StringBuilder
      var i = 0
      while i < s.length do
        val c = s.charAt(i)
        if c == '%' && i + 4 < s.length then
          try
            b.append(Integer.parseInt(s.substring(i + 1, i + 5), 16).toChar)
            i += 5
          catch case _: NumberFormatException =>
            b.append(c)
            i += 1
        else
          b.append(c)
          i += 1
      b.toString

  /** Wrap the shown form of an interpolated argument in a marker. */
  def wrap(kind: String, attrs: List[(String, String)], text: String): String =
    val attrStr = attrs.map((k, v) => s"$k=${encode(v)}").mkString(AttrSep.toString)
    s"$Start$kind$AttrsSep$attrStr$TextSep${plain(text)}$End"

  enum Node:
    case Text(text: String)
    case Marked(kind: String, attrs: List[(String, String)], text: String)

  /** Parse a marked-up string. Robust against truncated or stray marker
   *  characters: anything that does not form a complete marker is dropped and
   *  the surrounding content treated as plain text.
   */
  def parse(s: String): List[Node] =
    val nodes = mutable.ListBuffer[Node]()
    val text = new StringBuilder
    def flush() =
      if text.nonEmpty then
        nodes += Node.Text(text.toString)
        text.clear()
    var i = 0
    while i < s.length do
      val c = s.charAt(i)
      if c == Start then
        val end = s.indexOf(End, i + 1)
        val kindEnd = s.indexOf(AttrsSep, i + 1)
        val attrsEnd = if kindEnd < 0 then -1 else s.indexOf(TextSep, kindEnd + 1)
        if end < 0 || kindEnd < 0 || attrsEnd < 0 || kindEnd > end || attrsEnd > end then
          i += 1
        else
          flush()
          val kind = s.substring(i + 1, kindEnd)
          val attrs = s.substring(kindEnd + 1, attrsEnd) match
            case "" => Nil
            case as =>
              as.split(AttrSep).toList.map: kv =>
                kv.split("=", 2) match
                  case Array(k, v) => (k, decode(v))
                  case _           => (kv, "")
          nodes += Node.Marked(kind, attrs, s.substring(attrsEnd + 1, end))
          i = end + 1
      else if c == End || c == AttrsSep || c == TextSep then
        i += 1
      else
        text.append(c)
        i += 1
    flush()
    nodes.toList

  /** The string with all markers removed, keeping only the visible text. */
  def plain(s: String): String =
    if !s.exists(c => c >= Start && c <= TextSep) then s
    else
      parse(s).map {
        case Node.Text(text)         => text
        case Node.Marked(_, _, text) => text
      }.mkString

  /** A subtree of a diagnostic type that was replaced by a string-literal
   *  placeholder before pickling, so that the pickled type resolves against the
   *  classpath alone. `definedAt` points at the source definition of the local
   *  symbol, when there is one; `printed` is the display form of the replaced
   *  subtree.
   */
  final case class Placeholder(
    id: Int, kind: String, name: String, arity: Int, definedAt: String, printed: String)

  /** The reserved prefix of placeholder literal types. A genuine string literal
   *  type starting with this prefix is escaped with `escapedLiteral`.
   */
  final val PlaceholderPrefix = "⟨scala-diag:"

  def placeholderText(id: Int): String = s"$PlaceholderPrefix$id⟩"

  def escapedLiteral(s: String): String = s"${PlaceholderPrefix}esc:$s⟩"

  private def encodeField(s: String): String = encode(s).replace("|", "%007c")

  def encodePlaceholder(p: Placeholder): String =
    List(p.id.toString, p.kind, p.name, p.arity.toString, p.definedAt, p.printed)
      .map(encodeField).mkString("|")

  def decodePlaceholder(s: String): Option[Placeholder] =
    s.split("\\|", -1) match
      case Array(id, kind, name, arity, definedAt, printed) =>
        try Some(Placeholder(
          decode(id).toInt, decode(kind), decode(name), decode(arity).toInt,
          decode(definedAt), decode(printed)))
        catch case _: NumberFormatException => None
      case _ => None
