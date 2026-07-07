package scala.meta.internal.pc

import scala.language.unsafeNulls
import java.{util => ju}

import scala.meta.pc.AutoImportsResult

import org.eclipse.lsp4j.TextEdit

case class AutoImportsResultImpl(
    packageName: String,
    edits: ju.List[TextEdit],
    override val symbol: ju.Optional[String]
) extends AutoImportsResult
