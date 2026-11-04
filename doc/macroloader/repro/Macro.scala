package repro

import scala.quoted.*

object Macro:
  // Expands to whichever Lib the macro's class loader resolves at expansion time.
  inline def version: String = ${ versionImpl }
  def versionImpl(using Quotes): Expr[String] = Expr(repro.lib.Lib.version)
