import language.experimental.captureChecking
import language.experimental.separationChecking

class Counter extends caps.Mutable:
  private var count: Int = 0
  private update def bump(): Unit = count += 1

  inline update def next(): Int =   // inlined at call sites outside Counter
    bump()                          // rewritten to a synthetic accessor for bump
    count                           // rewritten to inline$count
