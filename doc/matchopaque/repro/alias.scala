package lib

type Cell[value] = value match
  case Int => Cell.Whole
  case _   => Cell.Ref[value]
