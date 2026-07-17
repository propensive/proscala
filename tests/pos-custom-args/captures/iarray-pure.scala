import language.experimental.captureChecking

// `IArray` results are pure: although the opaque alias dealiases to (mutable)
// `Array`, the interface exposes no mutation, so construction is semantically
// `caps.freeze`. Each of these previously produced `IArray[...]^{fresh}`.
object Test:
  val literal: IArray[Int] = IArray(1, 2, 3)
  val empty: IArray[String] = IArray.empty[String]

  def fromList(xs: List[Int]): IArray[Int] = IArray.from(xs)
  def slicePure(a: IArray[Int]): IArray[Int] = a.slice(0, 1)
  def dropPure(a: IArray[Int]): IArray[Int] = a.drop(1)
  def appendPure(a: IArray[Int], b: IArray[Int]): IArray[Int] = a ++ b
  def tabulated(n: Int): IArray[Int] = IArray.tabulate(n)(identity)

  // A pure class may hold an IArray field built from fresh parts.
  class Holder(parts: List[Int]):
    val data: IArray[Int] = IArray.from(parts)
