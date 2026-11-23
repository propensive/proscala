//> using options -Zdiagnostic-givens

import scala.util.NotGiven
import Givens.given

trait Present
given Present = new Present {}

def notGivenOfPresent = summon[NotGiven[Present]] // error
