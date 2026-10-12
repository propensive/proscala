def describe(x: String | Null): Int =
  if x != null then x.length
  else x.hashCode   // flow typing does not narrow `x` to `Null` here, so this
                    // branch alone does not reach the crash

// A receiver statically typed `Null` does: `hashCode` is dispatched on a
// receiver of class Null.
def describeNull(x: Null): Int = x.hashCode
