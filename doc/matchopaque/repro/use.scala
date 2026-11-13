package use

import lib.*

object Aliased:
  val ref: Cell[String] = Cell("a")
  def read(): String = ref()
  def swap(): String = ref.swap("b")

object Direct:
  val ref: Cell.Ref[String] = Cell("a")
  def read(): String = ref()
  def swap(): String = ref.swap("b")

object Inferred:
  val ref = Cell("a")
  def read(): String = ref()
  def swap(): String = ref.swap("b")
