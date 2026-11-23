import language.experimental.captureChecking

// A tracked value conforms to a refinement of its type which mentions the value
// itself. Its capture set is that of the expected type, or part of it, but the
// refinement was then checked against the value's widened type, which no longer
// says which value it is: "capability `any` cannot flow into capture set {reader}".

class Terrain
abstract class Reader(val view: Terrain^) { type Topic; val terrain: Terrain^ }

def same(reader: Reader^): (Reader { type Topic = reader.Topic })^{reader} = reader

def member(reader: Reader^)
:   (Reader { type Topic = reader.Topic; val terrain: Terrain^{reader.terrain} })^{reader} =
  reader

def function(reader: Reader^): Int =
  val read: (Reader { type Topic = reader.Topic })^ => Int = _ => 0
  read(reader)
