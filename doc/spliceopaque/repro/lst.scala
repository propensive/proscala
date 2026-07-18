package lib

opaque type Lst[+element] = List[element]

object Lst:
  def range(start: Int, end: Int): Lst[Int] = List.range(start, end)
  extension [element](list: Lst[element])
    def stdlibList: List[element] = list
    def map[element2](lambda: element => element2): Lst[element2] = list.map(lambda)
