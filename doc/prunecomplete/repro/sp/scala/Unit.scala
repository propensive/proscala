// A stand-in for the standard library's scala.Unit, shadowed on the sourcepath.
package scala
final abstract class Unit private extends AnyVal
@scala.annotation.compileTimeOnly("no companion")
object Unit extends AnyValCompanion
