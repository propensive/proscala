# Vendored Scala.js IR sources

These sources are a vendored copy of the Scala.js **IR** library
(`org.scala-js:scalajs-ir_3:1.22.0`, sources artifact), with a one-off package
migration applied:

    org.scalajs.ir  ->  dotty.tools.sjs.ir

They are compiled directly into `scala3-compiler` so that the compiler's Scala.js
back-end (`dotty.tools.backend.sjs.*`) can emit `.sjsir` without taking a binary
dependency on a `scalajs-ir` build produced by a different Scala compiler.

This mirrors what the sbt build does at build time (fetch + shade via
`project/Shading.scala`), but done once and committed so the simplified Makefile
build only has to compile ordinary sources.

Upstream: https://github.com/scala-js/scala-js (IR module), BSD 3-Clause license.
To refresh for a new Scala.js version, re-fetch the sources jar and re-apply the
`org.scalajs.ir` -> `dotty.tools.sjs.ir` substitution.
