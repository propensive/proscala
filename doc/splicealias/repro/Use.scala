// Use.scala
import language.experimental.captureChecking

val tc: TC { type Self = String } = Macro.make[String]
