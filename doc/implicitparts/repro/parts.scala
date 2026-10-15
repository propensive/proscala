import scala.compiletime.summonFrom

inline def next[value](using items: List[value]): value = items.head

def fuse[value](lambda: List[value] ?=> Any): Any = lambda(using Nil)

trait Adm[t]
class Box[child]

transparent inline def box(child: Any): Box[child.type] =
  summonFrom:
    case given Adm[child.type] => (new Box).asInstanceOf[Box[child.type]]
    case _                     => (new Box).asInstanceOf[Box[child.type]]

def test: Any = fuse(box(next))
