import language.experimental.captureChecking
import language.experimental.separationChecking

// Without a declared meet, two unrelated classifiers are still rejected.
trait Durable extends caps.SharedCapability, caps.Classifier
trait Scoped extends caps.SharedCapability, caps.Classifier

trait Sink extends Durable, Scoped: // error
  def log(message: String): Unit

// A meet that derives from only one of the pair does not reconcile the other.
trait Half extends Durable, caps.Classifier
trait Mixed extends Half, Scoped: // error
  def run(): Unit
