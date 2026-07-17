import language.experimental.captureChecking

// A recursive by-name implicit whose resolution is memoized into a synthetic
// `$_lazy_implicit` dictionary class. When a memoized entry is capability-typed —
// here `intFoo`'s result captures the ambient `Cap`, and the recursive `pair`
// entries transitively hold it — constructing the dictionary (`new <dictionary>`)
// captures those capabilities. The dictionary instance val must therefore be typed
// with an inferred capture set rather than the bare class type; otherwise capture
// checking rejects the capturing constructor with
// `Found: <dict>^{...}  Required: <dict>`.
class Cap
trait Foo[T]

object Foo:
  implicit def intFoo(implicit c: Cap^): Foo[Int]^{c} = new Foo[Int] {}
  implicit def pair[T, U]
      (implicit fe: => Foo[Int]^, fooT: => Foo[(T, U)]^, fooU: => Foo[(U, T)]^): Foo[(T, U)] =
    new Foo[(T, U)] {}
  implicit def string: Foo[String] = new Foo[String] {}

def test(implicit c: Cap^): Foo[(Int, String)] = implicitly[Foo[(Int, String)]]
