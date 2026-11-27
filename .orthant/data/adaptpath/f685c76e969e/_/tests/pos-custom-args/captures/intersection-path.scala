import scala.language.experimental.captureChecking

trait Parsing:
  type Self

trait Gathering:
  type Self
  def gathered(elements: List[Any]): Self

def keep[value](value: value): value = value

def read(parsing: Parsing^): Any = parsing match
  case gathering: Gathering => keep[gathering.Self](gathering.gathered(Nil))
  case _                    => ()
