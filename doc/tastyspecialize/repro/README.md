# Reproduction: tastyspecialize

One file, with `-experimental -language:experimental.inlineTraits`: an inline
trait `Counter` whose method calls an inline extension, a class `Doubler`
extending it, and a `main` which prints `4`.

```
F="-experimental -language:experimental.inlineTraits"
scalac $F -d a counter.scala
scala -classpath a app.Main                                    # 4

scalac $F -from-tasty -d b -classpath a a/app/Counter.tasty    # fails without the patch
scalac $F -from-tasty -d c -classpath a a/app/Doubler.tasty    # compiles, wrongly, without it
```

Without the patch — upstream 3.10.0 and `main` alike — the trait's unit does not
recompile:

```
-- Error: counter.scala:11:38
11 |  def advance(): Unit = count = count.twice
   |                                      ^^^^^
   |               method twice is declared as `inline`, but was not inlined
```

and the class does, to a constructor which calls `Counter.$init$`. An inline
trait has no initializer, so running `Main` with that `Doubler.class` in place
of the original gives

```
java.lang.NoSuchMethodError: 'void app.Counter.$init$(app.Counter)'
```

With the patch all four units recompile and the result prints `4`.
