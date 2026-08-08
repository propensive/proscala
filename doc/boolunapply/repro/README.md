# Reproduction: boolunapply

Compile the single file with no flags at all:

```
scalac repro.scala
```

The `language.experimental.captureChecking` import in the file is the entire
configuration; deleting it makes the file compile unpatched. No macro or
inline machinery is needed — a plain `match` triggers the bug.

Without the patch, compilation fails at the pattern: the capture-checking
augmentation has rewritten the synthesized `C.unapply`'s Boolean result to the
scrutinee singleton `x.type`, so the pattern's type no longer conforms to the
Boolean an empty-pattern match requires:

```
-- [E007] Type Mismatch Error: repro.scala:6:7 ---------------------------------
6 |  case C() => true
  |       ^
  |       Found:    (x5 : (x : C))
  |       Required: Boolean
  |
  | longer explanation available when compiling with `-explain`
1 error found
```

With the patch, the file compiles. The nullary case class is the
discriminating trigger: giving `C` a parameter (`case class D(n: Int)` matched
with `case D(n) =>`) makes the unpatched compiler accept the file, because a
parameterful unapply really does return the scrutinee under the augmentation.

Reduced from mandible's `Opcode` patterns (`case Wide() | Breakpoint | ... =>`
in `mandible.Bytecode`); the same mechanism broke anthology's
`case CompilerError() =>` inside contingency's `mitigate` macro, where the
re-spliced match reports the error as `Found: C^{x} Required: Boolean`.
