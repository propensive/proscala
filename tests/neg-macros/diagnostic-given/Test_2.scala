import scala.annotation.implicitNotFound
import Givens.given

@implicitNotFound("annotation message")
trait Missing

def test = summon[Missing] // error
