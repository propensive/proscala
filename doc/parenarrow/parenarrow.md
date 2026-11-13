# Forget a parenthesized type's elements once it is not a parameter list

Stops the 3.9 parser crashing on a function type whose parameter is a parenthesized type with a capture set, such as `(A & B)^ ?=> T`.

## Context

A type that begins with `(` can be several things, and the parser does not know
which until it has read past the closing parenthesis:

```scala
(A, B) => C      // the parameter list of a function type
(A, B)           // a tuple
(A & B)          // just a parenthesized type
(A & B)^ => C    // a parenthesized type, with a capture set, as a parameter
```

So `Parsers.typ` reads the elements first and decides afterwards. Function
parameters can be marked `erased`, and the parser has to remember which were;
on 3.9 it keeps that in a buffer, `erasedArgs`, adding one entry for each
element as it reads it. If an arrow follows the `)`, the elements were
parameters, and the function type is built from them and the buffer.

If no arrow follows, the elements were a tuple or a parenthesized type, and the
parser carries on with the rest of the type: a refinement, an annotation, an
infix operator, or — under capture checking — a capture set, `^`. Only then
does it look for an arrow again. If it finds one, the whole type read so far is
the *single* parameter of a function type, and the parser adds one entry to the
buffer for it.

But the entries for the elements inside the parentheses were still there. For
`(A & B)^ ?=> T` the buffer held two entries — one for `A & B` as a supposed
parameter, one for `(A & B)^` as the real one — and the function type was built
with one parameter. `FunctionWithMods` asserts that the two agree.

## Reproduction

[`repro/`](repro/) — one file:

```scala
import language.experimental.captureChecking

trait A
trait B

def f[T](block: (A & B)^ ?=> T): T = ???
```

```
Exception in thread "main" java.lang.AssertionError: assertion failed
    at dotty.tools.dotc.ast.untpd$FunctionWithMods.<init>(untpd.scala:83)
    at dotty.tools.dotc.parsing.Parsers$Parser.functionRest$1(Parsers.scala:1781)
```

A context function is the surest way in, because a context function type is
always built as a `FunctionWithMods`. Since the crash is in the parser, it can
also surface while an unrelated error is being rendered: the message's code
snippet is re-parsed for syntax highlighting, and the assertion then hides the
error that was being reported.

Soundness met it designing a typeclass whose method takes a block with a
capability in context, `(block: (Result & Granting[grants])^ ?=> result)` —
the natural way to write it.

## Solution

When the parentheses turn out not to be a parameter list, what was recorded for
their elements is dropped (`parsing/Parsers.scala`):

```scala
else
  // The parenthesized types are not a function's parameters after all, so
  // what was recorded for each as one does not describe the parameter
  // that the whole type may yet turn out to be, as in `(A & B)^ => C`.
  erasedArgs.clear()
  val tuple = atSpan(start):
    makeTupleOrParens(args.mapConserve(convertToElem))
```

Nothing is lost by it: that branch is taken only when none of the entries is
`true`, since an `erased` element sends the parser down the function path
whether or not an arrow follows. The later check that rejects `erased` outside
a function type therefore sees what it saw before.

## Bounds

Upstream removed the buffer altogether in 0114fb812f6 ("Simplify erased
parameters"), which is on `main` and in every 3.10 release, so the patch is
`obsolete-from` that commit and exists only for the 3.9 line, where upstream's
3.9.0 and `lts-3.9` both still crash.
