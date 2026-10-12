import scala.scalajs.wit
import scala.scalajs.wit.annotation.*
import scala.scalajs.wit.{Result, Ok}

object Host {
  @WitImport("example:host/utils@0.1.0", "log")
  def log(message: String): Unit = wit.native
}

@WitExportInterface
trait Run {
  @WitExport("wasi:cli/run@0.2.0", "run")
  def run(): Result[Unit, Unit]
}

@WitImplementation
object RunImpl extends Run {
  def run(): Result[Unit, Unit] = {
    Host.log("Hello from a Scala WASM component!")
    Ok(())
  }
}
