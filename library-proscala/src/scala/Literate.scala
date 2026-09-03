package scala

import annotation.experimental

/** A permission for the compiler to re-type literal values.
 *
 *  When an instance of `Literate[T]` for a literal's type `T` is in scope, and
 *  the literal appears where its ordinary type is not already required, the
 *  compiler rewrites the literal to `instance.convert(literal)`. The instance
 *  decides the result type through `Result`; by convention it is a refinement
 *  carrying the literal's singleton type, e.g. `Text { type Original = "foo" }`,
 *  so that no information is lost.
 *
 *  `convert` is not a member of this trait: an implementation restriction
 *  prevents a deferred inline method from being invoked through the trait
 *  type. Instead, each instance is a named class declaring a concrete
 *
 *  {{{
 *  inline def convert(inline value: From): Result
 *  }}}
 *
 *  which the compiler resolves on the instance's own type, so that the
 *  conversion can be inlined away entirely (for an opaque-alias target the
 *  literal reaches bytecode unchanged).
 */
@experimental
trait Literate[-From]:
  type Result
