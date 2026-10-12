import dotty.tools.io

@main def useVirtualDir(): Unit =
  val dir = io.virtualDirectory("scratch")
  println(s"name=${dir.name} empty=${dir.iterator.isEmpty}")
