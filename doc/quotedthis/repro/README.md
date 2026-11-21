# Reproduction: quotedthis

No flags. Three macros, each of which expands to an anonymous subclass of

```scala
abstract class Base(protected val table: Array[Int]):
  def index(key: Int): Int
```

whose `index` reads the inherited `table`; `Use.scala` calls the macro and
prints `index(1)`, which is `2`. Each is compiled on its own, then `Use.scala`
against it:

```
scalac -d Protected Protected.scala && scalac -cp Protected -d Protected Use.scala
scalac -d Public    Public.scala    && scalac -cp Public    -d Public    Use.scala
scalac -d Plain     Plain.scala     && scalac -cp Plain     -d Plain     Use.scala
scala -cp Protected Use             # 2, and the same for the other two
```

With the patch all three compile and print `2`. Without it, each fails in its
own way.

**`Protected.scala`** reads `table` from a quote nested in a splice,
`${body('key, '{table})}`. It compiles, and so does `Use.scala`, with a warning
at the macro call:

```
-- Warning: Use.scala:3:5
3 |    System.out.println(Macro.make(1).index(1))
  |     ^
  |     Infinite recursive call
```

Running it never returns: the accessor made for `table` calls itself.

```
  public int[] inline$table();
    Code:
         0: goto          0
```

**`Public.scala`** is the same with `val table`, not `protected val table`.
Compiling it crashes the compiler:

```
java.lang.AssertionError: assertion failed: unresolved symbols: anonymous class Base {...} (line 12) when pickling Public.scala
	at dotty.tools.dotc.core.tasty.TreePickler.pickle(TreePickler.scala:952)
	at dotty.tools.dotc.quoted.PickledQuotes$.pickle(PickledQuotes.scala:234)
```

**`Plain.scala`** has no nested splice at all: `def index(key: Int): Int = table(key)`,
with `table` protected. It compiles, and `Use.scala` is rejected:

```
-- Error: Use.scala:3:33
3 |    System.out.println(Macro.make(1).index(1))
  |                       ^^^^^^^^^^^^^
  |undefined: this.inline$table.apply # -1: TermRef(TermRef(ThisType(TypeRef(NoPrefix,class $anon)),inline$table),apply) at inlining
```

Upstream 3.9.0 and 3.10.0 behave the same as Proscala without the patch.
