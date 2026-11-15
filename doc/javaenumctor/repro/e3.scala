enum Color extends java.lang.Enum[Color]:
  case Red, Green

@main def e3(): Unit =
  println(Color.Red)
  println(java.lang.Enum.valueOf(classOf[Color], "Green"))
