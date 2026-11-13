import language.experimental.captureChecking

trait A
trait B

def f[T](block: (A & B)^ ?=> T): T = ???
