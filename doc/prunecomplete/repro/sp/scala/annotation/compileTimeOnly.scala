// A stand-in for the standard library's scala.annotation.compileTimeOnly, shadowed on the sourcepath.
package scala.annotation
final class compileTimeOnly(message: String) extends scala.annotation.StaticAnnotation
