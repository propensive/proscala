# adaptpath

Keeps a stable reference of intersection type as a reference when box adaptation has nothing to change, so that types which depend on it stay paths.

## Context

A **path-dependent type** names a member of a particular value:
`gathering.Self` is the `Self` of the object `gathering` refers to, and is a
different type from the `Self` of any other `Gathering`. For the compiler to
treat an expression as having such a type, it must keep track of the fact that
the expression *is* `gathering` — its singleton type, `gathering.type` — and
not merely that it has `gathering`'s declared type. Once the reference is
widened to its type, `gathering.Self` can only be read as the projection
`Gathering#Self`: the `Self` of some `Gathering` or other, which conforms to
nobody's `Self` in particular.

Capture checking rechecks every expression against its expected type, and as
part of that it *adapts boxes*: it compares the box status of the capture sets
in the actual and the expected type and inserts or removes boxes where they
differ. It does this on the widened type of the expression, and is written to
be conservative: if adaptation returns the widened type unchanged, the original
type, singleton and all, is kept.

scala/scala3 #27394 added a step to that adaptation. An intersection of two
capturing types, `A^{c1} & B^{c2}`, is first rewritten to `(A & B)^{c1 ** c2}`,
so that its capture set can be unboxed like any other. But the rewritten type
was returned unconditionally:

```scala
case AndType(tp1 @ CapturingType(parent1, refs1), tp2 @ CapturingType(parent2, refs2))
if tp1.isBoxed == tp2.isBoxed =>
  return recur(
    CapturingType(AndType(parent1, parent2), refs1 ** refs2, tp1.isBoxed),
    expected, covariant)
```

It is never the type that came in, so the caller always concludes that
something was adapted and drops the reference. From 3.10.2-RC1 on, any stable
reference whose type is such an intersection loses its identity wherever it is
rechecked, and every type that depends on it turns into a projection.

## How to reproduce it

Compiled with `-experimental`:

```scala
import scala.language.experimental.captureChecking

trait Parsing:
  type Self

trait Gathering:
  type Self
  def gathered(elements: List[Any]): Self

def keep[value](value: value): value = value

def read(parsing: Parsing^): Any = parsing match
  case gathering: Gathering => keep[gathering.Self](gathering.gathered(Nil))
  case _                    => ()
```

```
Found:    (Parsing & Gathering)#Self
Required: gathering.Self
```

A variable bound by a typed pattern has the scrutinee's type meeting the
pattern's — here `Parsing & Gathering`, each operand with a capture set of its
own — which is exactly the shape the new step rewrites.

The parsers of [Soundness](https://soundness.dev)'s xylophone (XML) and
stratiform (TEL) do this. A field's decoder is matched against a `Gathering`
refinement, which a repeatable field's decoder has, and the collected children
are handed to it:

```scala
case gathering: Gathering if entries.readUnchecked(index)(1).repeatable =>
  ...
  values(index) =
    if focused then focus(descend(prior, key))(gathering.gathered(elements))
    else gathering.gathered(elements)
```

## Solution

The new step is made conservative in the way the step beside it, for match
types, already is: if adapting the rewritten type changes nothing, the type
that came in is returned.

```scala
val pulled = CapturingType(AndType(parent1, parent2), refs1 ** refs2, tp1.isBoxed)
val adapted = recur(pulled, expected, covariant)
return if adapted eq pulled then actual else adapted
```

and likewise for unions. Where a box does have to be inserted or removed the
result is what upstream computes; only the case in which nothing had to be
done is different, and there the caller keeps the reference, as it does for
every other type.

The patch is always on: it removes a spurious error which 3.10.0 and 3.10.1 do
not report. It applies from #27394 on.
