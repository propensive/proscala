# inlineaccessor

Stops separation checking from treating an accessor the inliner generates as a definition which hides the instance it reads.

## Context

**Separation checking** makes sure that two references through which the same
mutable state can be reached are not used as if they were independent. One of
its rules concerns a definition whose type carries a *fresh* capability — one
written `^`, promising that the value is separate from everything else. If the
value in fact holds part of the enclosing object, that part is **hidden**
behind the fresh capability, and the object may no longer be used directly:

```scala
class Decoder extends caps.Mutable:
  private var buffer: Array[Byte] = new Array[Byte](8)
  def output: Array[Byte] = buffer        // result type Array[Byte]^{any.rd}
  update def reset(): Unit = ...          // error: `this` is hidden by `output`
```

Since scala/scala3 #27524 the rule also applies where the fresh capability is
read-only, as the one implied for an array type is. For a method the programmer
wrote, that is a tightening with a remedy: the result can be given the type it
really has, `Array[Byte]^{this.rd}`.

It also reaches a method the programmer did not write. An `inline` method is
copied into its callers, which may not be able to see the `protected` or
`private` members its body uses. The inliner therefore generates an **inline
accessor** for each such member — a public method named `inline$<member>`
which returns it — and rewrites the body to call that. For an array field the
accessor's result type is `Array[T]^{any.rd}`, the checker takes it for a
definition hiding the instance, and every later use of `this` in the class is
an error. Nothing in the source can prevent this: the accessor's type is not
written anywhere, and annotating the field `@untrackedCaptures` does not reach
it.

## How to reproduce it

Compiled with `-experimental`:

```scala
import scala.language.experimental.captureChecking
import scala.language.experimental.separationChecking
import scala.language.experimental.inlineTraits

object Cursor:
  inline trait Snapshot[operand] extends caps.Stateful:
    @caps.unsafe.untrackedCaptures
    protected var cells: scala.Array[operand] = null.asInstanceOf[scala.Array[operand]]
    protected var pos: Int = 0
    protected inline def peek: operand = cells(pos)

class Parser extends caps.Mutable, Cursor.Snapshot[Byte]:
  private var count = 0
  update def step(): Byte =
    count += 1
    peek
```

```
Separation failure: Illegal access to {Parser.this} which is hidden by the previous definition
of method Cursor$Snapshot$$inline$cells with result type Array[Byte]^{any.rd}.
```

This is the shape of `zephyrine.Cursor.Snapshot` in
[Soundness](https://soundness.dev): an inline trait which gives each parser a
directly typed view of the input buffer, so that `peek` on a parser of bytes
is a `byte[]` load. Every parser extending it — the YAML parser first — was
rejected at each of its own statements.

## Solution

An inline accessor stands for a selection of the member. Where the selection
is written out, `this.cells`, it is a use of `this` and hides nothing; the
same read made through `inline$cells` should behave no differently. The patch
leaves inline accessors out of the definitions separation checking examines and
records:

```scala
private def isInlineAccessor(sym: Symbol)(using Context): Boolean =
  sym.name.unexpandedName.is(InlineAccessorName)

def checkValOrDefDef(tree: ValOrDefDef)(using Context): Unit =
  val sym = tree.symbol
  if !sym.isOneOf(TermParamOrAccessor)
     && !sym.needsResultRefinement
     && !isAssumedSeparate(tree.rhs)
     && !isCoverageLiftedTemp(tree)
     && !isInlineAccessor(sym)
  then
    ...
```

The name is *unexpanded* before it is tested, since an accessor copied out of
an inline trait carries the trait's name as a prefix
(`Cursor$Snapshot$$inline$cells`).

Only the accessor's own definition is exempt. A method the programmer wrote
with the same result type is checked as before, and so are the uses of what
the accessor returns, at each place the inline method is expanded.

The patch is always on: it removes a spurious error which 3.10.0 and 3.10.1 do
not report. It applies from #27524 on.
