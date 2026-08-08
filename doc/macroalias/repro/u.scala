package reprouse
import repro.*

@main def run(): Unit =
  val a: internal.Date = opNoArg()
  val b: internal.Date = opArg(Monthstamp())
  println((a, b))
