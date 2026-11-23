// A local inline method which reads private members of its class. Read back from TASTy,
// `Encoder.this` in the method's body was not recognised as the prefix of the call, so
// the inliner bound it to a proxy, through which a private member cannot be selected:
// "value raster cannot be accessed as a member of (Encoder_this : ...)".

final class Encoder(raster: Array[Int], width: Int):
  def total(): Int =
    inline def word(x: Int): Int = raster(x.min(width - 1))

    var sum = 0
    var x = 0

    while x < width do
      sum += word(x)
      x += 1

    sum
