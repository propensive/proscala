import language.experimental.captureChecking

// Expanding `succ` needs `Macro`, which is compiled in this same run, so this
// unit is suspended and re-compiled in a fresh run.
inline def succ(x: Int): Int = ${Macro.succ('x)}

def use(n: Int): Int =
  val set = new scala.collection.immutable.TreeSet[Int]()
  succ(n)
