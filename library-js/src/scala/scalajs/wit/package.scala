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
   *  classOf[R], <wit-result-type>, classOf[P0], arg0, classOf[P1], arg1, ...
   *  }}}
   *
   *  i.e. the result carrier first (as `classOf[R]`, or `classOf[Unit]` for a
   *  `void` function, giving the erasure-safe IR result type) followed by the
   *  WIT result type as a *structured descriptor* — a tree of calls to the
   *  `wit*` marker functions below, e.g.
   *  `witList(witTuple(witPrim("string"), witPrim("string")))` — because
   *  `classOf` erases the nested type arguments such a result needs. Then one
   *  `classOf[P]` / argument pair per parameter, in order. Each `classOf[P]`
   *  must denote a type that maps to the Component Model (a primitive, an
   *  unsigned type, `String`, an `Array`, a `@WitRecord`, `@WitVariant` or
   *  `@WitFlags` type, a WIT resource, `Result` or `java.util.Optional`)
   *  exactly as for an `@WitImport` parameter. The caller is expected to cast
   *  the `Any` result to the real result type.
   */
  def witImportCall(module: String, name: String, sigAndArgs: Any*): Any = native

  /** A WIT primitive type, by its WIT name: `"bool"`, `"u8"`, `"u16"`, `"u32"`,
   *  `"u64"`, `"s8"`, `"s16"`, `"s32"`, `"s64"`, `"f32"`, `"f64"`, `"char"` or
   *  `"string"`. Part of `witImportCall`'s structured result-type descriptor;
   *  never evaluated.
   */
  def witPrim(name: String): Any = native

  /** A named WIT type — a resource, record, variant, flags or enum — given by
   *  the Scala class that represents it (a `@WitResourceImport` trait, or a
   *  `@WitRecord`/`@WitVariant`/`@WitFlags`-annotated type). Part of
   *  `witImportCall`'s structured result-type descriptor; never evaluated.
   */
  def witNamed(cls: Class[?]): Any = native

  /** A WIT `list` of the given element type. Part of `witImportCall`'s
   *  structured result-type descriptor; never evaluated.
   */
  def witList(elem: Any): Any = native

  /** A WIT `tuple` of the given component types. Part of `witImportCall`'s
   *  structured result-type descriptor; never evaluated.
   */
  def witTuple(elems: Any*): Any = native

  /** A WIT `option` of the given payload type. Part of `witImportCall`'s
   *  structured result-type descriptor; never evaluated.
   */
  def witOption(elem: Any): Any = native

  /** A WIT `result` with the given `ok` and `err` arm types (`witUnit` for an
   *  absent arm). Part of `witImportCall`'s structured result-type descriptor;
   *  never evaluated.
   */
  def witResult(ok: Any, err: Any): Any = native

  /** An absent `result` arm (WIT `_`). Part of `witImportCall`'s structured
   *  result-type descriptor; never evaluated.
   */
  def witUnit: Any = native

  /** A parameter-type slot of `witImportCall` whose WIT type needs more than
   *  `classOf` can carry (e.g. `option<string>`, whose payload type `classOf`
   *  erases): `cls` is the carrier class (the IR-level type the argument is
   *  lowered as) and `descriptor` the structured WIT type, as a tree of the
   *  other `wit*` markers. Never evaluated.
   */
  def witParam(cls: Class[?], descriptor: Any): Any = native

}
