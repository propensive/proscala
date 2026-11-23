import lib.*

object Test:
  inline def first[value](refs: List[Cell.Ref[value]]): value = refs.head()

  def read(): String = Holder.ref()
  def swap(): String = Holder.ref.swap("b")
  def whole(): Int = Holder.whole()
  def head(): String = Holder.refs.head()
  def nested(): String = first(Holder.refs)
