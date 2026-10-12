import language.experimental.captureChecking

extension [value](iterable: Iterable[value])
  inline def fuse[state](base: state)(lambda: (state, value) ?=> state): state =
    val iterator: Iterator[value] = iterable.iterator
    var state: state = base
    while iterator.hasNext do state = lambda(using state, iterator.next())
    state

def fold[acc](initial: acc)(lambda: (Int, acc) => Exception => acc): acc =
  val errors = List[Exception]()
  (0 until errors.length).fuse(initial)(lambda(summon[Int], summon[acc])(errors(summon[Int])))
