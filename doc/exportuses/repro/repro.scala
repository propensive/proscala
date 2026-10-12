import language.experimental.captureChecking
import language.experimental.separationChecking
package lib:
  trait Producer[medium] extends caps.ExclusiveCapability, caps.Stateful:
    type Transport
    update def put(m: medium): Unit
  trait Intake[medium] extends Producer[medium]:
    update def finish(): Unit
  trait Stream[medium] extends caps.ExclusiveCapability, caps.Stateful:
    type Transport
  extension [medium, transport, target <: (Intake[medium] { type Transport = transport })](consume intake: target^)
    def ingest(consume stream: (Stream[medium] { type Transport = transport })^): target^ =
      intake.finish()
      intake
  class Gather extends Intake[Int]:
    type Transport = Unit
    update def put(m: Int): Unit = ()
    update def finish(): Unit = ()
    var data: Int = 0
  def stream(): (Stream[Int] { type Transport = Unit })^ = new Stream[Int] { type Transport = Unit }
package umbrella:
  export lib.ingest
package client:
  import umbrella.ingest
  def use(): Int =
    val gather = lib.Gather()
    val gathered = gather.ingest(lib.stream())
    gathered.data
