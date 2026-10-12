# Reproduction

`repro.scala` stands in for Soundness: `arrays.A` is an opaque alias over the mutable
`scala.Array` (as `proscenium.Array` is), classified mutable by `-Zopaque-mutability`, and
`decimal.D` is an opaque alias over its frozen form `A[Int]^{}` (as `hypotenuse.Decimal` was
over `scala.IArray[Int]` because this failed).

    scalac -Ycc-new -language:experimental.captureChecking \
           -language:experimental.separationChecking \
           -Zopaque-mutability -Zpure-iarrays repro.scala

fails with

    Separation failure: value back's type decimal.D^{any.rd} hides non-local this of class object D.

(and, in a module with more holders, `object D needs to extend Capability since it has a
field `zero` with `any` in its type`). Adding `-Zfrozen-pure` compiles it.
