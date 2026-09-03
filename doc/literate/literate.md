# Re-type literals through a `Literate` instance in scope

Lets a library decide what a literal means: where a `scala.Literate`
instance exists for a literal's type, and the expected type does not already
require the literal as it is, the literal is re-typed as the instance's
result — `Text { type Topic = "foo" }` in place of `"foo"`, with the
singleton preserved as a type member. Nothing is added to the language
surface, and with no instance in scope nothing changes at all.

Enabled by `-Z:literate-literals` ([zflags](../zflags/zflags.md)); without it, upstream's code runs at every site this patch touches.

## Context

Scala hard-codes the types of literals: `"foo"` is a `java.lang.String`,
`42` an `Int`. A library that offers a safer alternative — Soundness's
`Text`, an opaque alias over `String` that hides `String`'s partial methods —
can convert at the boundary, but it cannot make a literal *be* its type. That
gap is not cosmetic. Given

```scala
trait Show[-value]
given text: [text <: Text] => Show[text] = ...
def display[value: Show](value: value): Text
```

the call `display("foo")` fails: the literal types as `String`, the type
parameter instantiates to `String`, and no `Show[String]` exists. The
library's answer today is to publish a second, redundant instance for
`String` beside every instance for `Text` — 28 files in Soundness did exactly
that — or to write `"foo".tt` at every site, of which Soundness had 336.

`FromDigits` solves the same problem for numeric literals only, and only
where the expected type is already known; it declines precisely the case
above, where the expected type is an uninstantiated type variable.

## The permission

`scala.Literate[From]` grants exactly one thing: a literal of type `From` may
be re-typed. It is consulted only at a literal, so unlike a `Conversion` it
never fires on a member selection of some other expression.

```scala
@experimental
trait Literate[-From]:
  type Result
```

`convert` is deliberately *not* a member of the trait: an implementation
restriction prevents a deferred inline method from being invoked through the
trait type. Each instance is a named class declaring a concrete

```scala
inline def convert(inline value: From): Result
```

which the compiler resolves on the instance's own type, so the conversion
inlines away. For an opaque-alias target the literal reaches bytecode
unchanged: `ldc "foo"` into a `String`-erased field, or `bipush 42` into an
`int`. A Soundness-style instance reads

```scala
final class TextLiterate[str <: String & Singleton] extends Literate[str]:
  type Result = Text { type Topic = str }
  inline def convert(inline value: str): Result = value.asInstanceOf[Result]
```

The `Topic` member carries the literal's singleton type, so nothing is lost:
a consumer binds it back with `[topic <: String & Singleton](value: Text {
type Topic = topic })`, and `constValue`/`ValueOf` work as before. A
refinement is used rather than an intersection (`Text & "foo".type`) because
the intersection is a subtype of `String`, which would make every partial
`String` method reachable again and defeat the point of the opaque type.

## When a literal is re-typed

String literals are re-typed in `Typer.typedLiteral`, numeric literals in
`typedNumber`'s fallback — after the expected-type-driven `FromDigits` cases,
which keep precedence. The rewrite is speculative: if the converted literal
does not type, the original failure is restored verbatim.

A literal keeps its ordinary type when the expected type already accepts it —
a `String` parameter, a `String & Singleton` bound, a singleton type's own
path — and in every position where a literal must stay a constant or is
matched structurally:

- patterns, type positions, and `inline val` right-hand sides;
- annotation arguments, which are read back as constants (`@targetName`) —
  suppressed in `ProtoTypes.typedArg`, which retracts `Mode.InAnnotation`
  and so defeats a mode test at the literal;
- **quote patterns**, where a literal is matched against the literal a
  macro's caller wrote (see the reproduction);
- inline expansions, rechecking, and overload-resolution argument
  pre-typing, where arguments are ranked against a wildcard.

A selection is the one place the rule is deliberately strict: with an
instance in scope, `"foo".charAt(5)` is an error rather than a partial
`String` method, because the instance's API *is* the literal's API.
`("foo": String).charAt(0)` remains the way through, and where the target
type offers an unwrapping member — Soundness's `Text.s` — `"foo".s` reads
better.

The feature is inert unless `scala.Literate` exists and an instance is in
scope, so a library that does not use it observes no change: Soundness's
14,196 compilation targets are unaffected until its instance is imported.

## Reproduction

`repro/` holds the quote-pattern case, which is the subtlest of the
positions above and the only defect found that changed behaviour rather than
rejecting code. Compile `macro.scala` (with an instance in scope) and then
`use.scala`, and run `qpuse.run`: it must print
`matched-empty-literal-case`. Without the `Mode.isQuotedPattern` gate the
pattern's own literal is converted, the pattern stops matching a caller's
plain `String`, and the program prints `fell-through-to-generic` — silently
taking the wrong branch. This is what made every named-argument HTTP
response in Soundness's `telekinesis` fail to compile with a message about
a header named `""`.
