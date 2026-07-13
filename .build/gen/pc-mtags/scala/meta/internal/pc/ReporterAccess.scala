package scala.meta.internal.pc

import scala.language.unsafeNulls
trait ReporterAccess[Reporter] {
  def reporter: Reporter
}
