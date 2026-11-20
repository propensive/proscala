# Keep the implied capture set out of an opaque alias seen in its scope

Stops the capture checker reading a frozen opaque array in a type argument, `Box[A[T]^{}]`, as `Box[Array[T]^{any.rd}]` in some compilation runs and not in others, by keeping the capture set a capability implies out of the alias that an opaque type's own scope sees.

Always on: it turns a spurious error into an accepted program, and changes nothing else.

## Context

Under capture checking a type that derives from a capability carries an implied
capture set wherever it is written without one. With separation checking,
`Array` is such a type: a plain `Array[Int]` means `Array[Int]^{any.rd}`, a
read-only view, and `Array[Int]^{}` is a *frozen* array, which no reference can
write through. Soundness's immutable arrays are exactly that — `Data` is
`Array[Byte]^{}` — over its own opaque `proscenium.Array`:

```scala
opaque type Array[element] = scala.Array[element]

object Array:
  def quoted[element: Type](elements: Array[Expr[element]]^{})(using Quotes)
  :   Expr[Array[element]^{}]
```

An opaque alias is transparent inside its scope. The compiler implements that
with a refinement of the self type of the class that owns the alias, here the
package object: `this: Array$package.type { type Array[element] = scala.Array[element] }`.
A reference to the alias through `this`, which is how the companion's
signatures name it, finds the right-hand side there.

`Setup`, the phase that prepares types for the capture checker, transforms the
info of every capture-checked class it is asked about, the self type included.
It adds the implied capture set to the right-hand side as to any other type, so
the refinement becomes `type Array[element] = scala.Array[element]^{any.rd}`.
For a type alias's *own* info `Setup` strips that set again (`type X = C`, not
`type X = C^{any}`), since each use of the alias implies it anew. The refinement
kept it.

## The problem

With the set in the alias, an `Array[T]^cs` written in scope acquires the root
when it is dealiased, and capturing types fuse: `(scala.Array[T]^{any.rd})^{}`
is `scala.Array[T]^{any.rd}`. `Setup` dealiases the type arguments of an applied
type to box them, so the result type above, read from TASTy, became
`Expr[scala.Array[element]^{any.rd}]` — the alias seen through and its empty set
replaced — and a caller expecting the frozen array was rejected.

But only sometimes. The reference `this.Array` computes its denotation from the
class's info, and it finds the transformed info only if it is first asked for
at the capture-checking phase, after the class has been transformed. Selecting
any other member of the companion whose signature mentions the alias does that.
A denotation computed before then keeps the alias as written, and the signature
is read correctly. So the outcome depended on what else the run had looked at:

```scala
def first(xs: Array[Int]^{}): Box[Array[Int]^{}] =
  Array.boxed(xs)              // accepted

def client(xs: Array[Int]^{}): Box[Array[Int]^{}] =
  val size = Array.size(xs)
  Array.boxed(xs)              // Found: Box[Array[Int]^{any.rd}]
```

That is how it showed in Soundness: a clean build of `stratiform.core` compiled
every source in one run and passed, while an incremental recompilation of a
single file of the same module, against the unchanged TASTy of `proscenium`,
failed on three calls to `Array.quoted` — with no source change between them,
and cured by cleaning the module. [`repro/`](repro/) has the two-file form; it
needs no `-Z` flag, and upstream 3.9.0, 3.10.0 and 3.10.1 fail in the same way.

## The solution

The refinement is treated as the alias's own info is. When `Setup` maps a class
info, it strips the implied capture set from the alias refinements of the self
type, looking under the type lambda of a parameterized alias:

```scala
// cc/Setup.scala, in transformExplicitType's type map
override def mapClassInfo(tp: ClassInfo): ClassInfo =
  def stripAlias(alias: Type): Type = alias match
    case alias: HKTypeLambda =>
      alias.derivedLambdaType(resType = stripAlias(alias.resType))
    case _ =>
      stripImpliedCaptureSet(alias)
  def stripOpaqueAliases(self: Type): Type = self match
    case self @ CapturingType(parent, refs) =>
      self.derivedCapturingType(stripOpaqueAliases(parent), refs)
    case self @ RefinedType(parent, rname, rinfo: TypeAlias) =>
      self.derivedRefinedType(
        stripOpaqueAliases(parent), rname, rinfo.derivedAlias(stripAlias(rinfo.alias)))
    case _ =>
      self
  val tp1 = super.mapClassInfo(tp)
  tp1.selfInfo match
    case self: Type if self ne tp.selfInfo =>
      tp1.derivedClassInfo(selfInfo = stripOpaqueAliases(self))
    case _ =>
      tp1
```

Only a set that `Setup` itself implied is removed (`stripImpliedCaptureSet`
recognises it by its class); a capture set written in the alias's right-hand
side, as in `opaque type Frozen = Array[Byte]^{}`, stays. The alias the scope
sees is then the same whichever info a reference happens to find — the one from
before capture checking or the transformed one — so the order of the run no
longer matters, and it is the reading that every run which passed already had.
Nothing is lost by it: a bare `Array[T]` written in scope still gets its
implied set where it is written, because the alias still derives from the
capability.

The patch does not change how a stale denotation comes to be seen at an earlier
phase, which is general compiler machinery; it removes the difference that made
it visible here. `tests/pos-custom-args/captures/opaque-frozen-argument` covers
a parameterized and a plain alias across two compilation runs.
