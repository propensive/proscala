import language.experimental.captureChecking

// An `AnyKind`-bounded type parameter must not constrain its argument's capture
// set: `AnyKind` is the top of the kind lattice, so it says nothing about
// captures, exactly as `Any` says nothing. `Type`/`TypeRepr.of` are declared
// this way, so without this a capture-checked macro cannot mention a function
// type reflectively.
object Test:
  def anyKindBound[T <: AnyKind]: Unit = ()
  def anyBound[T]: Unit = ()

  def impureViaAnyKind = anyKindBound[Int => Int]
  def impureViaAny = anyBound[Int => Int]

  def reflected(using q: quoted.Quotes) =
    import q.reflect.*
    TypeRepr.of[Int => Int]
