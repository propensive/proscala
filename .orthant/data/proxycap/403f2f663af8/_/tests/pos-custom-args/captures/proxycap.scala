// A closure passed for a non-inline function parameter of an inline method may
// capture what the parameter allows. Where the parameter's function type may capture
// anything (`=>`, `?=>`), the proxy's capture set is inferred, so it is exactly what
// the closure captures: not a fresh `any`, which separation checking would reject as
// hiding the captured references from their later uses.
import language.experimental.separationChecking

extension [value](iterable: Iterable[value])
  inline def fuse[state](base: state)(lambda: (state, value) ?=> state): state =
    val iterator: Iterator[value] = iterable.iterator
    var state: state = base
    while iterator.hasNext do state = lambda(using state, iterator.next())
    state

  inline def each(lambda: Int ?=> value => Unit): Unit =
    iterable.foreach(lambda(using 0))

inline def twice[result](action: () => result): result =
  action()
  action()

inline def runOnly(io: Object^)(action: () ->{io} Unit): Unit = action()

def fold[acc](initial: acc)(lambda: (Int, acc) => Exception => acc): acc =
  val errors = List[Exception]()
  (0 until errors.length).fuse(initial)(lambda(summon[Int], summon[acc])(errors(summon[Int])))

def run(io: Object^): Unit =
  twice(() => println(io))
  List(1, 2).each(x => println(io))   // a capturing function in the closure's result
  println(io)                         // io is not hidden by either proxy
  runOnly(io)(() => println(io))      // an explicit capture set is kept

// Any other argument's proxy is inferred, and bounded by its parameter's declared type.
class Res extends caps.SharedCapability
inline def useOnly(io: Res)(x: Object^{io}): Unit = println(x)
inline def useAny(x: Object^): Unit = println(x)

def legit(io: Res, o: Object^{io}): Unit =
  useOnly(io)(identity(o))
  useAny(identity(o))

// An array in an argument's type is not declared as a fresh capability.
class Buf:
  def array(): Array[Byte] | Null = new Array[Byte](4)

def size(bytes: Array[Byte]): Int = bytes.length
def bufSize(b: Buf): Int = size(b.array().nn)

// An inferred capture-set argument bounds nothing.
extension [element, refs^](array: Array[element]^{refs})
  inline def len: Int = array.length

def lengths(a: Array[Int]^{}, n: Int): Int = identity(a).len + Array.fill(n)(0).len
