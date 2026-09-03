# smap

`-Z:inline-source-maps`: emit JSR-45 SourceDebugExtension (SMAP) attributes that map inlined
code back to the source files it was written in.

Enabled by `-Z:inline-source-maps` ([zflags](../zflags/zflags.md)); without it, upstream's code runs at every site this patch touches.

## Context

Scala 3 `inline` methods and macros splice code from one source file into
classes generated from another, but a JVM classfile can name only a single
source file, and its `LineNumberTable` holds bare line numbers within that
file. The compiler therefore deliberately destroys inlined-code provenance:
when `Inlined` nodes are dropped at Erasure, `Inlines.reposition` rewrites
every tree that came from another file to the span of the call, with the
comment *"Until we implement JSR-45, we cannot represent in output positions
in other source files."* A crash inside a macro-expanded or inline-def body
reports the caller's line, and debuggers cannot step through an inline body in
its own file. Soundness makes unusually heavy use of transparent inline
methods and macros, so a single reported line routinely stands in for a deep
stack of inlined calls.

JSR-45 ("Debugging Support for Other Languages") is the standard fix, used by
JSP containers and, most relevantly, by Kotlin for its inline functions. A
small text table (an "SMAP") is embedded in each classfile as the
`SourceDebugExtension` attribute. Synthetic line numbers beyond the end of the
real source file are allocated for inlined code — if `Main.scala` has 120
lines, inlined code gets output lines 121, 122, … — and the SMAP maps each
synthetic line back to a real `(file, line)` pair. JSR-45-aware debuggers
(IntelliJ; anything speaking JDWP's `SetDefaultStratum`) resolve the mapping
transparently; naive consumers just see large line numbers.

## Reproducing the limitation

```scala
// Util.scala
object Util:
  inline def twice(inline x: Int): Int =
    x + x        // without -Z:inline-source-maps, this line is unrepresentable in Main.class

// Main.scala
class Main:
  def run(): Int =
    Util.twice(21)
```

Compiling without the flag, every instruction of the expansion carries line 3
of `Main.scala` (the call), and `javap -v Main.class` shows no
`SourceDebugExtension`. A breakpoint on `x + x` in `Util.scala` can never bind
in `Main`.

## Solution

The patch keeps call-site spans exactly as before — no downstream phase or
pickling invariant changes — and adds provenance alongside them:

- As Erasure drops each `Inlined` node (innermost first), trees inlined from
  another source accumulate an attachment holding their **chain of inline
  frames**: the position the code was written at, then each enclosing inline
  call site. When the outermost call is dropped, each distinct chain is
  resolved to a synthetic line number, allocated past the end of the unit's
  primary source by a per-unit registry (`SmapRegistry`).
- The backend's `lineNumber` prefers the resolved synthetic line, and the
  registry is serialized into ASM's `visitSource(name, debug)` second
  parameter — the `SourceDebugExtension` slot, previously always `null`.

Three strata are emitted; the first two mirror Kotlin's `Kotlin`/`KotlinDebug`
pair:

- **`Scala`** (default): synthetic line → the position the code was written
  at. This is what debuggers use for breakpoints and stepping.
- **`ScalaDebug`**: synthetic line → its inline call site, with the call
  site's line given *in output numbering*. Real lines map to themselves, so a
  consumer can follow `ScalaDebug` through nested inlining, one call per hop,
  until it reaches a real line — recovering the full stack of inline "calls"
  hidden inside one JVM stack frame.
- **`ScalaClass`**: synthetic line → the binary name of the top-level class
  whose compilation unit the inlined code was written in, carried as the
  stratum's "file" names (its input lines are always 1). A source position
  alone names no class, and there is no contract from file names to class
  names, so this is what lets tooling find the class's TASTy — and with it
  the inline method's definition — without guessing. The class is taken from
  the `Inlined` node's call trace, which references exactly that class.

For the example above (`Main.scala` having 3 lines):

```
SMAP
Main.scala
Scala
*S Scala
*F
+ 1 Main.scala
Main.scala
+ 2 Util.scala
Util.scala
*L
1#1,3:1
3#2:4
*S ScalaDebug
*F
+ 1 Main.scala
Main.scala
+ 2 Util.scala
Util.scala
*L
3#1:4
*S ScalaClass
*F
1 Util
*L
1#1:4
*E
```

Output line 4 is synthetic: the `Scala` stratum maps it to `Util.scala:3`
(where `x + x` lives), `ScalaDebug` maps it to line 3 of `Main.scala`
(the call), and `ScalaClass` names `Util` as the top-level class whose TASTy
holds the inline method's definition. The JVM itself never consults SMAP for stack traces, so a raw
trace through inlined code shows the synthetic numbers; remapping is a
consumer-side job — an IDE, or a renderer such as Soundness's Digression
module, which can read the attribute and expand each frame into its inline
chain. Code inlined from sources with no line information (e.g. TASTy without
line sizes, virtual sources) safely falls back to the old call-site-only
behaviour, as does everything when the flag is off (the default).
