package scala

import scala.annotation.experimental

/** Witnesses that a value of type `T` may be spliced into a vararg position,
 *  `f(value*)`, and gives the `Seq` or `Array` it spreads to.
 *
 *  A `T*` parameter is a `Seq[T]` underneath, so only a `Seq` or an `Array` can
 *  normally be spliced. An abstraction that hides one of those — an opaque type
 *  alias over `Vector`, say — cannot be, and neither can an unrelated type that
 *  merely has a sequence of elements to offer.
 *
 *  A `Spreadable` instance grants that permission for one type, at splice
 *  positions only. It is not a [[Conversion]]: it never applies to a member
 *  selection, so the abstraction stays opaque everywhere else.
 *
 *  `Out` must be given concretely by the instance, since it is the type the
 *  splice is elaborated against:
 *
 *  ```scala
 *  object Series:
 *    opaque type Series[+e] = Vector[e]
 *    // written where the alias is transparent, so this is the identity
 *    given [e] => (Spreadable[Series[e]] { type Out = Vector[e] }) =
 *      new Spreadable[Series[e]]:
 *        type Out = Vector[e]
 *        def spread(value: Series[e]): Vector[e] = value
 *  ```
 *
 *  When the value's representation already is `Out` — the opaque-alias case —
 *  the compiler elaborates the splice as a cast, which is a no-op at erasure,
 *  and `spread` is never called. Otherwise `spread` is invoked to convert.
 */
@experimental
trait Spreadable[T]:

  /** The `Seq` or `Array` that `T` spreads to. An instance must specify this
   *  concretely, e.g. `Spreadable[Foo] { type Out = Vector[Bar] }`.
   *
   *  Deliberately unbounded. `<: Seq[?] | Array[?]` would be the honest bound
   *  but cannot be written: an opaque alias over an `Array` — `IArray` itself,
   *  for one — does not conform to it outside its defining scope, which is the
   *  very situation this type exists to serve. The compiler checks at the
   *  splice site instead, seeing through opaque aliases as it does so.
   */
  type Out

  /** Convert `value` to the sequence spliced into the vararg position. Not
   *  called when `T`'s representation is already `Out`.
   */
  def spread(value: T): Out
