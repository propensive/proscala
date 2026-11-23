// A type alias in a refinement means the type it names, not that type with the capture
// set implied by a capability bound: `{ type Self = handle }` with `handle <: Res^`
// does not mint a fresh root at each instantiation of the given.

trait Res extends caps.SharedCapability:
  def size: Int

trait Streamable:
  type Self
  def stream(s: Self): Int

object Res:
  given streamable: [handle <: Res^] => (Streamable { type Self = handle }) = _.size

extension [source](source: source)(using st: Streamable { type Self = source })
  def checksum: Int = st.stream(source)

def f(r: Res^): Int = r.checksum
def g(using r: Res^): Int = summon[Res^].checksum
