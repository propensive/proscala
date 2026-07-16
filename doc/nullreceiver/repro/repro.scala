def describe(x: String | Null): Int =
  if x != null then x.length
  else x.hashCode   // here x is flow-typed to Null; hashCode is dispatched
                    // on a receiver of class Null
