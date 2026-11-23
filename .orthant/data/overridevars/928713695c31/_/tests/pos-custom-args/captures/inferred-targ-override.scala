// A type argument inferred for an inline call gets a capture set variable of its own
// wherever it occurs in the expansion. In a class there, the ones in a method's parameter
// type and in the type the overridden method takes its parameter type from must be unified
// for the override to be accepted.

class Point

trait Member:
  type Self
  def text(value: Self): String

trait Param[A]:
  def text(value: A): String

inline def member[value](x: value): Member { type Self = value } =
  new Member:
    type Self = value
    def text(arg: value): String = "x"

inline def param[value](x: value): Param[value] =
  new Param[value]:
    def text(arg: value): String = "x"

inline def nested[value](x: value): Param[List[value]] =
  new Param[List[value]]:
    def text(arg: List[value]): String = "x"

// A SAM type for which the platform makes a class is expanded to one before capture checking
inline def memberSam[value](x: value): Member { type Self = value } = arg => "x"
inline def paramSam[value](x: value): Param[value] = arg => "x"

def test(point: Point, io: Point^) =
  member(point)
  param(point)
  nested(point)
  memberSam(point)
  paramSam(point)
  member(point).text(io)
  memberSam(point).text(io)
