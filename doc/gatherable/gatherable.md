# Receive repeated parameters as the type a `Gatherable` instance names

Lets the body of a method see a repeated parameter (`xs: T*`) as a collection type of the author's choosing, converted once on entry through a `scala.Gatherable` instance in scope, instead of as the standard library's `Seq[T]`.

Enabled by `-Zgatherable-varargs` ([zflags](../zflags/zflags.md)); without it, upstream's code runs at the one site this patch touches. `scala.Gatherable` ships in the supplementary `proscala-library` jar, not in `scala3-library`; see [compatibility.md](../compatibility.md).

## Context

A repeated parameter is a `Seq[T]` underneath: that is what a caller passes,
and what the body of the method sees.

```scala
def total(xs: Int*): Int = xs.sum     // xs: Seq[Int]
```

Soundness's prelude hides the standard collections behind opaque aliases, so
that only its own total, typeclass-driven API is visible. A repeated parameter
is the one place the language itself hands such code a standard-library
collection, and every method that takes one begins by converting it:

```scala
def apply(children: Html*): Html = Fragment(children.to(List).compact.nodes)
```

A survey of Soundness found 138 repeated parameters; about ninety are
converted like this on the first line of the method, and the rest use `Seq`'s
own methods where Soundness's were meant.
[spreadable](../spreadable/spreadable.md) solved the opposite direction —
passing a Soundness collection *to* a repeated parameter. This is its
counterpart.

## The instance

`scala.Gatherable[T]` names the type repeated parameters of element type `T`
are received as, and converts to it:

```scala
@experimental
trait Gatherable[T]:
  type Out
  def gather(elements: Seq[T]): Out
```

One instance, generic in the element, serves a whole codebase:

```scala
given [e] => (Gatherable[e] { type Out = Series[e] }) =
  new Gatherable[e]:
    type Out = Series[e]
    def gather(elements: Seq[e]): Series[e] = elements.toVector
```

With that in scope and the flag on,

```scala
def total(xs: Int*): Int = xs.total   // xs: Series[Int]; `total` is Series's own
```

The instance is found by ordinary implicit search **where the method is
defined**, so it follows the usual rules: a lexically nearer instance wins,
and different parts of a program may receive their repeated parameters
differently. There is no default instance. A method with a repeated parameter
that has none in scope does not compile:

```
-Zgatherable-varargs: no given scala.Gatherable[Int] is in scope to receive this repeated parameter
```

That is deliberate: the flag states that no method in the module is to be
handed a `Seq`, and a silent fallback to `Seq` would break that statement
wherever an import was forgotten.

`Gatherable` is `@experimental`, like `Spreadable`, so a module using the flag
is compiled in experimental mode.

## Solution

The change is a desugaring, in `ast/Desugar.scala`, of each method definition:

```scala
def f(xs: T*) = body
```

becomes

```scala
def f(xs: T*) =
  val xs$1 = xs
  { val xs = scala.Gatherable.gather(xs$1); body }
```

The inner `val xs` shadows the parameter throughout the body; the outer block
exists only so that the conversion can still name the parameter. Nothing else
in the compiler changes. The typer resolves `Gatherable.gather`'s context
parameter at the position of the parameter, so a missing instance is reported
there, and infers the gathered value's type as the instance's `Out`. Because
the rewrite happens before naming, an inferred result type sees it too: `def
f(xs: Int*) = xs` has the result type `Series[Int]`.

**The signature is untouched.** The method still takes `T*`; its erasure,
its TASTy and its overriding relationships are what upstream produces. A
caller therefore needs neither the flag nor an instance, splices a `Seq` as
ever, and cannot tell how the method receives its arguments. The choice of
`Out` is private to the definition, and changing it is not a binary or source
incompatibility. This is why the search happens at the definition rather than
at each call: an `Out` chosen by callers would have to be part of the
signature, agreed across separately compiled modules, and understood by every
part of the compiler that handles repeated parameters today.

**The conversion runs once**, on entry, whether or not the body uses the
parameter. An instance for an opaque alias over the `Seq` a caller happens to
pass may return it unchanged, but in general `gather` copies.

**The elaboration goes through a method**, `Gatherable.gather[T]`, rather than
selecting `gather` on the instance. Under capture checking the difference
matters: `proscala-library` is compiled without capture checking, and a member
of such a trait cannot be applied at an element type that captures a
capability — `summon[Gatherable[() ->{log} Unit]].gather(fs)` is rejected,
with `Seq[() -> Unit]` required. A polymorphic method instantiates its own
type parameter at the call, and both `(fs: (() => Unit)*)` and
`(fs: (() ->{log} Unit)*)` are received without complaint.

## What is left as upstream has it

- **Class parameters**, including a case class's. A class parameter is a
  member, which a block in a body cannot shadow, and for a case class its type
  is also that of the field, the product element and the extractor's result.
  `case class Path(segments: Text*)` still has a `Seq[Text]` field. The idiom
  the feature makes cheap is to declare the field with the collection type and
  write the variadic factory by hand: `def apply(segments: Text*): Path = new
  Path(segments)`.
- **Macros** — the right-hand side of a macro must be the splice itself — and
  **`inline` parameters**, which a macro inspects as the caller wrote them
  (`Varargs`).
- **By-name repeated parameters** (`xs: => T*`), which the conversion on entry
  would force.
- **Compiler-generated methods**, such as a case class's `apply`.
- **Abstract methods**, which have no body.

Two consequences of the rewrite are worth knowing. The synthetic conversion
uses the parameter, so `-Wunused:params` no longer reports an unused repeated
parameter. And a body that forwards its parameter to another repeated
parameter (`g(xs*)`) now splices an `Out`, which needs `Out` to be a `Seq`, an
`Array`, or [spreadable](../spreadable/spreadable.md).

## The build

`Gatherable.gather` is the first method with a body in `proscala-library`.
Compiling one for Scala.js on a WASM tree sends the backend looking for
`scala.scalajs.wit.witImportCall`, which the downloaded Scala.js library
lacks, so the `proscala-library-sjs` step is now typed against the wit-baked
library, as `tasty-core-sjs` already was, and runs after it is built.
