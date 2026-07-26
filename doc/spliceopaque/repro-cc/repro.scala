// Compile with: -experimental -Ycc-new -language:experimental.captureChecking
//
// Proscala (3.9.0-RC4-p6): crashes in the capture checker —
//   assertion failed: TypeBounds(...Nothing, ...Node)
//   at Types$TypeBounds.<init> via TypeApplications.translateFromRepeated
//   from Recheck.isCompatible / CheckCaptures
//
// Mainline (3.9.0-RC4): clean type error at the splice —
//   Found: IArr[Node], Required: Seq[Node] | Array[? <: Node]
// (mainline has no spliceopaque, so the tree never reaches cc).
//
// The equivalent splice of an opaque alias over *List* is handled cleanly by
// spliceopaque under cc; only the Array/IArray-flavoured piercing produces a
// tree whose Repeated translation the capture checker cannot rebuild.
package splicecc

object IArr:
  def of[element](array: scala.IArray[element]): IArr[element] =
    array.asInstanceOf[IArr[element]]

opaque type IArr[+element] = scala.IArray[element]

trait Node
case class Fragment(nodes: Node*)

object Test:
  def make(nodes: IArr[Node]): Fragment = new Fragment(nodes*)
