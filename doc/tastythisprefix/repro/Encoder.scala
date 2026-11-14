package app

final class Encoder(raster: Array[Int], width: Int):
  def total(): Int =
    inline def word(x: Int): Int = raster(x.min(width - 1))

    var sum = 0
    var x = 0

    while x < width do
      sum += word(x)
      x += 1

    sum
