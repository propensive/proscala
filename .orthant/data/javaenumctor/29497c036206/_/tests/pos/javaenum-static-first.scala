// A reference to a static member of java.lang.Enum, typed before an enum which
// extends it, completed the class from its companion's loader; the class then kept
// only its two-parameter constructor, and the enum's parent call lacked arguments.
object Lookup:
  def green: Color = java.lang.Enum.valueOf(classOf[Color], "Green")

enum Color extends java.lang.Enum[Color]:
  case Red, Green
