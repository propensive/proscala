object Use:
  def main(args: Array[String]): Unit =
    System.out.println(Macro.plain.index(1))
    val nested = Macro.nested
    System.out.println(nested.index(1))
    System.out.println(nested.count)
    System.out.println(Macro.two.index(1))
