import language.experimental.captureChecking
import language.experimental.separationChecking

// A declared classifier meet: `Both` derives from two unrelated classifiers, so it is the least
// classifier of anything extending it, and the pairwise inheritance check must accept it.
trait Durable extends caps.SharedCapability, caps.Classifier
trait Scoped extends caps.SharedCapability, caps.Classifier
trait Both extends Durable, Scoped, caps.Classifier

trait Sink extends Both:
  def log(message: String): Unit

trait Monitor extends Durable:
  def cancelled: Boolean

class Loop(iteration: () ->{caps.any.only[Durable]} Unit) extends Durable:
  def run(): Unit = iteration()

def task(body: () ->{caps.any.only[Durable]} Unit): Unit = body()

def use(monitor: Monitor^, sink: Sink^): Unit =
  task { () => if monitor.cancelled then () }
  task { () => sink.log("x"); monitor.cancelled }
  Loop(() => { sink.log("tick"); if monitor.cancelled then () }).run()
