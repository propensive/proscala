package app

object Use:
  enum Issue:
    case Expect(char: Char)
    case Missing

  def four: Int = Macro.twice(2)
