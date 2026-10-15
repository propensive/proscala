trait Typeclass { type Self }
trait Resultant { type Result }

infix type is[self, tc <: Typeclass] = tc { type Self = self }
infix type in[refined, form <: AnyKind] = refined { type Form = form }
infix type to[refined <: { type Result }, result] = refined { type Result = result }

class Chain
trait Aggregable extends Typeclass
trait Readable extends Typeclass, Resultant
trait Decodable extends Typeclass

object Decodable:
  given generic: [value] => value is Decodable in value = ???

def read[value, result](value: value)(using readable: (value is Readable to result)): result = ???

trait Protobuf
object Protobuf:
  given decodable: [value] => value is Decodable in Protobuf = ???
  given aggregableIn: [value] => (decodable: value is Decodable in Protobuf) => ((value in Protobuf) is Aggregable) = ???
  given chainReadable: [value]
  =>  ( aggregable: ((value in Protobuf) is Aggregable) )
  =>  ( (Chain is Readable to (value in Protobuf)) ) = ???

class Sample

def test = read[Chain, Sample in Protobuf](Chain())
