import language.experimental.captureChecking
import language.experimental.separationChecking

trait Stream extends caps.ExclusiveCapability, caps.Stateful:
  def start: Int
  update def skip(count: Int): Unit

trait Backend:
  def source(): Stream^

object Backends:
  // Typer ascribes the anonymous class instance below with `Stream`, the type it avoids
  // the class by; read back from TASTy, at the inline site, that ascription is a plain
  // type tree
  inline given backend: Backend = new Backend:
    private def readStream(start: Int): Stream^ =
      new Stream:
        private var start0: Int = start
        def start: Int = start0
        update def skip(count: Int): Unit = start0 += count

    def source(): Stream^ = readStream(1)
