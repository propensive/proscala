import scala.quoted.*

object Macros:
  inline def coded(): Unit = ${ codedMacro }
  inline def uncoded(): Unit = ${ uncodedMacro }

  def codedMacro(using Quotes): Expr[Unit] =
    quotes.reflect.report.errorAndAbort("[↯/s.87.1.2] the document is not valid")

  def uncodedMacro(using Quotes): Expr[Unit] =
    quotes.reflect.report.errorAndAbort("this macro gives no code")
