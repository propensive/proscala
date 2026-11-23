package lib

import java.util.concurrent.atomic as juca

object Cell:
  opaque type Whole = juca.AtomicInteger
  opaque type Ref[value] = juca.AtomicReference[value]

  def apply(initial: Int): Whole = juca.AtomicInteger(initial)
  def apply[value](initial: value): Ref[value] = juca.AtomicReference(initial)

  object Whole:
    extension (whole: Whole) inline def apply(): Int = whole.get()

  object Ref:
    extension [value](ref: Ref[value])
      inline def apply(): value = ref.get().nn
      inline def swap(value: value): value = ref.getAndSet(value).nn

type Cell[value] = value match
  case Int => Cell.Whole
  case _   => Cell.Ref[value]

// The declared types of these are read from TASTy by `Test_2.scala`, where they
// are unreduced applications of the match alias `Cell`.
object Holder:
  val ref: Cell[String] = Cell("a")
  val whole: Cell[Int] = Cell(1)
  val refs: List[Cell[String]] = List(Cell("a"))
