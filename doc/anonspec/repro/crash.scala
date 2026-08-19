class Base(x: Int)(using s: String)

given String = "ctx"

inline def make(): Base = new Base(1) {}

@main def crash() = println(make())
