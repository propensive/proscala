package app

object Trace:
  inline def fail(): Nothing = throw new RuntimeException("here")

  def main(args: Array[String]): Unit =
    try fail()
    catch case error: RuntimeException => println(error.getStackTrace.nn.head)
