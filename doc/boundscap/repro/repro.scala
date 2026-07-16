import language.experimental.captureChecking

def f(x: AnyRef { type Bcd = Array[Double] }): Unit = ()
