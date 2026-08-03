package lib

opaque type Lst[+element] = List[element]

object Lst:
  def range(start: Int, end: Int): Lst[Int] = List.range(start, end)
  // grants the splice permission; without it the splice is simply rejected
  given [element] => (Spreadable[Lst[element]] { type Out = List[element] }) =
    new Spreadable[Lst[element]]:
      type Out = List[element]
      def spread(value: Lst[element]): List[element] = value
  extension [element](list: Lst[element])
    def stdlibList: List[element] = list
    def map[element2](lambda: element => element2): Lst[element2] = list.map(lambda)
