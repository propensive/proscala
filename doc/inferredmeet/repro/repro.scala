import scala.language.experimental.captureChecking

trait Handle extends caps.ExclusiveCapability:
  type Under

trait Granting[+grants]

def open[filesystem, result](block: (Handle { type Under = filesystem } & Granting[Int]) ?=> result): result =
  val handle =
    new Handle with Granting[Int]:
      type Under = filesystem

  block(using handle)

class Monitor extends caps.SharedCapability
abstract class Worker(parent: Monitor^)

trait Daemon:
  type Result
  def name: String

def daemon(using monitor: Monitor^): Daemon =
  caps.unsafe.unsafeAssumePure:
    new Worker(monitor) with Daemon:
      type Result = Unit
      def name: String = ""
