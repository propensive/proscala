import language.experimental.captureChecking

// An `import scala.language.unsafeNulls` among a block's statements is in scope
// for the block's *result expression* too, not only for the statements that
// follow it. Under capture checking the block is rechecked, and the recheck used
// to drop the statements' context before rechecking the result expression, so
// every nullable value in the trailing expression was rejected.
//
// `direct` is a statement and always compiled; the `while` loop is the method
// body's result expression, and everything inside it used to fail with
// "Found: String | Null, Required: String".

object UnsafeNullsBlockExpr:
  def f(input: String, n: Int): Unit =
    import scala.language.unsafeNulls

    val direct: String = input.substring(0, 1)

    var i = 0

    while i < n do
      val inLoop: String = input.substring(0, 1)

      if i > 0 then
        val inIf: String = input.substring(0, 1)

        while i < n do
          val deep: String = input.substring(0, 1)
          i += 1

      i += 1
