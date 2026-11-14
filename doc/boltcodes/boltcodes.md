# `-Zbolt-codes`: a bolt code on every error and warning

With `-Zbolt-codes`, every error and warning the compiler reports is labelled with its **bolt code** — `[↯/p.1.7]` in place of `[E007]` — including the many that upstream leaves unnumbered, and those reported by macros.

## Context

A [bolt code](https://github.com/propensive/bolt) names a diagnostic in one form across all of Propensive's projects: `↯`, then `/`, a letter for the project (`p` is Proscala, `s` Soundness), and after a `.` a group of numbers — a subdivision of the project, an error in it, and optionally a variant and a call site. The `bolt` repository records what each code means, and a code, once assigned, is never reused.

Upstream numbers some of its messages: a type mismatch is `E007`, from the `ErrorMessageID` enumeration. But most places that report an error do so with a plain interpolated string, which has no number at all:

```scala
report.error(em"Traits cannot have secondary constructors", ctor.srcPos)
```

There are over six hundred of these, and they are printed under a bare `-- Error:` heading. Nor does an error reported by a macro have any identity, though for Soundness, most of whose compiletime checks are macros, these are the errors a user sees most.

## How to reproduce it

`repro/plain.scala` has one error upstream numbers and one it does not:

```scala
trait Shape:
  def this(sides: Int) = this()

val count: Int = "three"
```

```
-- [↯/p.7.40] Error: plain.scala:2:6 ---------------------------------------------
-- [↯/p.1.7] Type Mismatch Error: plain.scala:4:17 -------------------------------
```

Without the flag these are upstream's `-- Error:` and `-- [E007] Type Mismatch Error:`. `repro/macros.scala` defines two macros, one of which begins its message with a bolt code of its own, `[↯/s.87.1.2] the document is not valid`. Its error is reported as a **compound** code, the compiler's code for a macro's error carrying the macro's:

```
-- [↯/p.2.2/s.87.1.2] Error: coded.scala:1:25 ------------------------------------
1 |val result = Macros.coded()
  |             ^^^^^^^^^^^^^^
  |             the document is not valid
```

## The solution

Proscala's codes fall into subdivisions:

| Subdivision | |
| ----------- | - |
| `1` | the messages upstream numbers: `E007` is `↯/p.1.7`, and a message upstream adds takes its number here |
| `2` | `2.1`, a message with no code of its own; `2.2`, a message reported by a macro |
| `3`–`12` | the messages upstream does not number, by the part of the compiler that reports them: the driver, parsing, trees, core, the typer, metaprogramming, capture checking, the transformations, the JVM backend, and Scala.js with WebAssembly |

**Unnumbered messages are known by their template.** Giving each of six hundred call sites an identifier would make a patch that touched 150 files, to be remade for every upstream it is applied to. Instead the `em` interpolator, which makes nearly all of them, records the `StringContext` it was given:

```scala
def em(args: Shown*)(using Context): NoExplanation =
  NoExplanation(i(args*)).withBoltOrigin(sc)
```

The constant parts of that string, joined by `{}` with whitespace collapsed, are the message's key — `Traits cannot have secondary constructors{}` — and `reporting.BoltCodes` looks the key up in the registry, `mk/bolt-codes.tel`, from which the build writes the code of every key into the compiler's jar. The registry is a [TEL](https://github.com/propensive/tel) document:

```
subdivision 7 typer
  error 40
    source dotc/typer/Checking.scala
    template  Traits cannot have secondary constructors{}
```

**A message given as a plain string** — `report.warning("@SerialVersionUID does nothing on a trait", pos)`, of which there are some three hundred — has no `StringContext`, so it is known by its text. Its registry key is a `text` in place of a `template`: that text, with `{}` for each part the source does not fix (an interpolated value, or whatever is concatenated after the literal), and the compiler gives a message with no recorded template the code of the key its text fits; if it fits several, of the one that fixes most of it. Only a message whose string is built somewhere else, where it cannot be read out of the source, is left as `↯/p.2.1`.

`bin/proscala-bolt <registry> <tree>...` reads the templates and texts out of a tree's source and appends the new ones to the registry, each with the next number of its subdivision; with `--check` it lists them and fails. It never renumbers.

**The build runs that check.** Before compiling the compiler, `make` runs `bin/proscala-bolt --check` on the tree, and stops if any message lacks a code. So an upstream that adds a message cannot be built until the message is assigned one — which is one command and a commit of the registry — and no message reaches a release unnamed because nobody noticed it arrive. `make BOLT_CHECK=` builds regardless, for bisecting upstream or trying a nightly. When upstream rewords a message its template is a new error, and the `template` line may be moved to the old error by hand, since an error may have several. `mk/bolt-codes.tel` is a copy of `p.tel` in the `bolt` repository, and holds the templates of every upstream the patch has been applied to.

**A macro's message** goes through `BoltCodes.fromMacro`, which takes a leading bolt code — bracketed or not, coloured or not — out of the text and keeps it as the message's origin, to be shown after `/p.2.2` in the heading. A macro that gives no code is plain `↯/p.2.2`.

The code appears wherever upstream's number did: in the heading of the console message (and before the text of a message with no position), as a `boltCode` attribute of [semdiag](../semdiag/semdiag.md)'s XML, as the diagnostic code given to sbt's bridge, and as the LSP diagnostic code from the presentation compiler. Only errors and warnings have one. `-Wconf` and `@nowarn` are unchanged, and still select messages by upstream's `id=E7` and `name=`.

Without `-Zbolt-codes` the output is upstream's, to the byte.
