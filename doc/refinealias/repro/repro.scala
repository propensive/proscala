import language.experimental.captureChecking

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
