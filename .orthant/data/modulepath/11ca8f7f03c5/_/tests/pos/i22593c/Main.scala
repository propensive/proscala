// A type selected through an inline accessor for a qualified-private module.
// The accessor's result type must be the module's TermRef; if it is the module
// class's TypeRef instead, the accessor is not a legal path and every type
// selected through it (`Positional.Profile`) is rejected as unrealizable.
//
// The accessor lands in `Host`, a trait, so it cannot be final — which is what
// makes the realizability check depend on the result type being stable.
package p

private[p] object Positional:
  class Profile(val name: String)

trait Host:
  object Derivation:
    inline def make(): Int =
      val profiles: Array[Positional.Profile] = Array(Positional.Profile("a"))
      profiles.length

object Instance extends Host
