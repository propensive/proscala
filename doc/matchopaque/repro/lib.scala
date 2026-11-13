package lib

import java.util.concurrent.atomic as juca

object Cell:
  opaque type Whole = juca.AtomicInteger
  opaque type Ref[value] = juca.AtomicReference[value]

  def apply(initial: Int): Whole = juca.AtomicInteger(initial)
  def apply[value](initial: value): Ref[value] = juca.AtomicReference(initial)

  object Ref:
    extension [value](ref: Ref[value])
      inline def apply(): value = ref.get().nn
      inline def swap(value: value): value = ref.getAndSet(value).nn
