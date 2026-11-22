import scala.quoted.*

object TreeMacro:
  inline def explain(): Unit = ${explainImpl}

  // A macro's message is passed on as it was written, so a macro can mark its own up: here
  // a tree of two nodes, written out as text between and inside the markers that say so.
  def explainImpl(using Quotes): Expr[Unit] =
    def marked(kind: String, attributes: String, text: String): String =
      s"\uE000$kind\uE002$attributes\uE003$text\uE001"

    val leaf = marked("node", "role=propose\u001Fname=puck", " ▸ propose puck")
    val root = marked("node", "role=resolving\u001Fname=Fairy", s" ■ resolving Fairy\n └─$leaf")
    quotes.reflect.report.errorAndAbort(s"no fairy\n\n${marked("tree", "", root)}\n")
