// Same compilation as Internal.scala: this unit gets suspended to run 2
object Amount:
  // dependent method type: result mentions the parameter symbol `u`,
  // so integrate/IntegrateMap runs while typing it
  def name(u: Unit)(v: u.type): String = ""
  inline def apply[U]: String = ${ Internal.amount[U] }
