package dotty.tools
package dotc
package reporting

import java.io.PrintWriter

import core.Contexts.*
import interfaces.Diagnostic.{ERROR, WARNING}

/** A reporter that emits diagnostics as a stream of top-level XML `<diagnostic>`
 *  elements, with semantic markup for the fragments of each message that were
 *  interpolated from types, symbols, names or trees, as recorded by
 *  [[DiagnosticMarkup]]. Installed by `-Xsemantic-diagnostics`.
 *
 *  The output is a sequence of XML fragments, not a single document: consumers
 *  should parse each top-level element independently. Types carry their
 *  sanitized TASTy serialization, Base64-encoded, in a `tasty` attribute, and
 *  describe each placeholder that the sanitizer introduced in a nested
 *  `<placeholder>` element.
 */
class XmlReporter(writer: PrintWriter = new PrintWriter(Console.err, true))
extends Reporter with UniqueMessagePositions with HideNonSensicalMessages:

  import DiagnosticMarkup.Node

  private def escape(s: String): String =
    val b = new StringBuilder
    for c <- s do c match
      case '<'  => b.append("&lt;")
      case '>'  => b.append("&gt;")
      case '&'  => b.append("&amp;")
      case '"'  => b.append("&quot;")
      case c if c < ' ' && c != '\n' && c != '\t' => // illegal in XML 1.0
      case c    => b.append(c)
    b.toString

  private def stripAnsi(s: String): String = s.replaceAll("\u001B\\[[;\\d]*m", "")

  private def attr(name: String, value: String): String = s""" $name="${escape(value)}""""

  private def severity(level: Int): String =
    if level >= ERROR then "error"
    else if level >= WARNING then "warning"
    else "info"

  /** Marked-up message text as XML mixed content. */
  private def content(marked: String): String =
    DiagnosticMarkup.parse(stripAnsi(marked)).map {
      case Node.Text(text) => escape(text)
      case Node.Marked(kind, attrs0, text) =>
        val elem = kind match
          case "type" | "sym" | "name" | "code" => kind
          case _ => "span"
        val placeholders =
          attrs0.collect { case ("p", v) => v }.flatMap(DiagnosticMarkup.decodePlaceholder)
        val attrs = attrs0.collect { case (k, v) if k != "p" => attr(k, v) }.mkString
        val body = escape(text) + placeholders.map { p =>
          "<placeholder"
            + attr("id", p.id.toString)
            + attr("kind", p.kind)
            + (if p.name.nonEmpty then attr("name", p.name) else "")
            + (if p.arity != 0 then attr("arity", p.arity.toString) else "")
            + (if p.definedAt.nonEmpty then attr("definedAt", p.definedAt) else "")
            + attr("printed", p.printed)
            + "/>"
        }.mkString
        s"<$elem$attrs>$body</$elem>"
    }.mkString

  override def doReport(dia: Diagnostic)(using Context): Unit =
    val msg = dia.msg
    val sb = new StringBuilder
    sb.append("<diagnostic")
    sb.append(attr("severity", severity(dia.level)))
    sb.append(attr("kind", msg.kind.toString))
    if msg.errorId.errorNumber >= 0 then
      sb.append(attr("errorId", msg.errorId.toString))
      sb.append(attr("errorNumber", msg.errorId.errorNumber.toString))
    sb.append(attr("compilerVersion", config.Properties.versionNumberString))
    sb.append(attr("tastyVersion",
      s"${dotty.tools.tasty.TastyFormat.MajorVersion}.${dotty.tools.tasty.TastyFormat.MinorVersion}"
        + s"-${dotty.tools.tasty.TastyFormat.ExperimentalVersion}"))
    val pos = dia.pos
    if pos.exists && pos.source.exists then
      sb.append(attr("file", pos.source.file.path))
      sb.append(attr("line", (pos.line + 1).toString))
      sb.append(attr("column", (pos.column + 1).toString))
      sb.append(attr("endLine", (pos.endLine + 1).toString))
      sb.append(attr("endColumn", (pos.endColumn + 1).toString))
      sb.append(attr("start", pos.start.toString))
      sb.append(attr("end", pos.end.toString))
    sb.append(">")
    sb.append("<message>").append(content(msg.message)).append("</message>")
    if msg.canExplain then
      sb.append("<explanation>").append(content(msg.explanation)).append("</explanation>")
    sb.append("</diagnostic>")
    writer.println(sb.toString)
