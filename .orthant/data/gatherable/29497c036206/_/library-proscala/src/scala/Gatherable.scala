package scala

import scala.annotation.{experimental, implicitNotFound}

/** Decides the type a method body sees its repeated parameters of element type
 *  `T` as, in code compiled with `-Zgatherable-varargs`.
 *
 *  A `T*` parameter is a `Seq[T]`: that is what callers pass, and what the body
 *  of `def f(xs: T*)` normally sees `xs` as. Under `-Zgatherable-varargs` the
 *  body sees `xs` as the `Out` of the `Gatherable[T]` instance in scope where
 *  the method is defined, converted once on entry by `gather`. The method's
 *  signature is unchanged, so callers — compiled with the flag or without — are
 *  unaffected, and the choice of `Out` is private to the definition.
 *
 *  ```scala
 *  given [e] => (Gatherable[e] { type Out = Series[e] }) =
 *    new Gatherable[e]:
 *      type Out = Series[e]
 *      def gather(elements: Seq[e]): Series[e] = Series.from(elements)
 *
 *  def total(xs: Int*): Int = xs.sum    // `xs` is a `Series[Int]` here
 *  ```
 *
 *  There is no default instance: a method with a repeated parameter does not
 *  compile under the flag unless one is in scope.
 */
@experimental
@implicitNotFound("-Zgatherable-varargs: no given scala.Gatherable[${T}] is in scope to receive this repeated parameter")
trait Gatherable[T]:

  /** The type the body sees a repeated parameter of element type `T` as. An
   *  instance must specify it concretely, e.g.
   *  `Gatherable[e] { type Out = Series[e] }`.
   */
  type Out

  /** Convert the sequence of arguments the caller passed. Called once, on entry
   *  to the method.
   */
  def gather(elements: Seq[T]): Out

@experimental
object Gatherable:

  /** What the compiler elaborates the reception of a repeated parameter to: the
   *  arguments the caller passed, gathered by the instance in scope for their
   *  element type.
   */
  def gather[T](elements: Seq[T])(using gatherable: Gatherable[T]): gatherable.Out =
    gatherable.gather(elements)
