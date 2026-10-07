package scala.caps

import scala.annotation.experimental

/** The shared counterpart of `Unscoped`: a marker trait for shared capabilities that are not
 *  subject to scoping restrictions. A capability so classified may be aliased freely, as any
 *  `SharedCapability`, and may also be created at any level — the case of an ambient effect
 *  strategy that captures nothing scoped and is handed out by a polymorphic given at its use
 *  site. `Unscoped` itself extends `ExclusiveCapability`, so the two cannot be combined.
 *
 *  Shipped in the supplementary `proscala-library` jar, not in `scala-library`: the compiler
 *  looks it up leniently, so a classpath without it simply has no capability classified this
 *  way.
 */
@experimental
trait SharedUnscoped extends SharedCapability, Classifier
