// defs.scala — compiled WITH capture checking (defines the alias)
import language.experimental.captureChecking

class ParseError extends Exception

class Tactic[E <: Exception] extends caps.ExclusiveCapability

infix type raises[T, E <: Exception] = Tactic[E]^ ?=> T
