import language.experimental.captureChecking

case class C()

def check(x: C): Boolean = x match
  case C() => true
