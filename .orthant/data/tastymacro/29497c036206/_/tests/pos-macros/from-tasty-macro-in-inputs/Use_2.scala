// With `Macro_1` and `Other_2`, the inputs of a `-from-tasty` run in which this unit was
// suspended, although the macro it calls has its class file beside its TASTy file. The
// second run met the transformed tree of the first: "Conflicting definitions".

package app

object Use:
  enum Issue:
    case Expect(char: Char)
    case Missing

  def four: Int = Macro.twice(2)
