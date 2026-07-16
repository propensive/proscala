// client.scala — compiled WITH capture checking (calls the non-CC method)
import language.experimental.captureChecking

def client(using t: Tactic[ParseError]^): Int = Lib.parse("42")
