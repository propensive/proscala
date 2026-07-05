/*
 * Scala.js (https://www.scala-js.org/)
 *
 * Copyright EPFL.
 *
 * Licensed under Apache License 2.0
 * (https://www.apache.org/licenses/LICENSE-2.0).
 *
 * See the NOTICE file distributed with this work for
 * additional information regarding copyright ownership.
 */

package scala.scalajs

import scala.annotation.meta._

/** Types, methods and values for interoperability with Wasm Component Model libraries. */
package object wit {

  /** Denotes a method body as imported from Wasm Component. For use in facade types:
   *
   *  {{{
   *  class MyJSClass extends js.Object {
   *    def myMethod(x: String): Int = wit.native
   *  }
   *  }}}
   */
  def native: Nothing = {
    throw new java.lang.Error(
        "A method defined in a native JavaScript type of a Scala.js library " +
        "has been called. This is most likely because you tried to run " +
        "Scala.js binaries on the JVM. Make sure you are using the JVM " +
        "version of the libraries.")
  }

  /** Invokes a Wasm Component Model (WIT) imported function without a
   *  hand-written `@WitImport` facade method.
   *
   *  This is an intrinsic recognized by the Scala.js linker frontend: calls to
   *  it are lowered directly to a Wasm Component Model import invocation (the
   *  same lowering as a call to an `@WitImport`-annotated method), with the
   *  import declared on the enclosing class. It is intended to be emitted by
   *  code generators (e.g. Xenophile) that already know the WIT function's
   *  module, name and signature at compile time; it is not meant to be written
   *  by hand.
   *
   *  The signature is carried explicitly rather than through type parameters,
   *  so that it survives erasure. `module` and `name` are constant `String`
   *  literals identifying the WIT function. `sigAndArgs` is a flat, inline
   *  varargs list of the form:
   *
   *  {{{
   *  classOf[R], classOf[P0], arg0, classOf[P1], arg1, ...
   *  }}}
   *
   *  i.e. the result type first (as `classOf[R]`, or `classOf[Unit]` for a
   *  `void` function), then one `classOf[P]` / argument pair per parameter, in
   *  order. Each `Class[_]` must denote a type that maps to the Component Model
   *  (a primitive, an unsigned type, `String`, an `Array`, a `@WitRecord`,
   *  `@WitVariant` or `@WitFlags` type, a WIT resource, `Result` or
   *  `java.util.Optional`) exactly as for an `@WitImport` parameter/result. The
   *  caller is expected to cast the `Any` result to the real result type.
   */
  def witImportCall(module: String, name: String, sigAndArgs: Any*): Any = native

}
