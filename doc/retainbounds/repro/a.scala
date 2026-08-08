package rud
extension [value](iterable: Iterable[value])
  transparent inline def annex[right](lambda: value => right) = iterable.map: item =>
    inline compiletime.erasedValue[value] match
      case _: Tuple => (item, lambda(item))
      case _        => (item, lambda(item))
