import language.experimental.captureChecking

// What tests/pos-custom-args/captures/refined-singleton.scala accepts must not extend
// to a value whose capture set the expected type does not account for, or to a
// refinement the value's own member does not meet.

class Terrain
abstract class Reader(val view: Terrain^) { type Topic; val terrain: Terrain^ }

def pure(reader: Reader^): Reader { type Topic = reader.Topic } = reader // error
def less(reader: Reader^, other: Reader^): (Reader { type Topic = reader.Topic })^{other} = reader // error
def member(reader: Reader^): (Reader { val terrain: Terrain })^{reader} = reader // error
