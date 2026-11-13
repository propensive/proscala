# Reproduction: semdiag, a type that cannot be pickled

A program against the compiler's API that formats one type the way a
diagnostic message does, with the semantic markup active: a reference to a
method's parameter, taken out of the method type that binds it. Such a type
cannot be pickled, since pickling writes a parameter reference as a pointer to
its binder.

```
scalac -classpath <compiler jars> -d . Repro.scala
java -cp .:<compiler jars> Repro <scala-library.jar> marked
java -cp .:<compiler jars> Repro <scala-library.jar> plain
```

With the markup active, formatting a type pickles it so that its TASTy can be
embedded. Before the fix, the pickler's failure was reported by formatting the
same type — with the markup still active, so by pickling it again, without end:

```
Exception in thread "main" java.lang.StackOverflowError
```

(on a thread with a large stack, `OutOfMemoryError` instead, after a log full
of "error when pickling type"). With the fix the type is formatted, without
TASTy:

```
formatted: …(r : Object)…
```

`plain` formats the same type with the markup off, which never pickled
anything, and is what the compiler does without `-Zsemantic-diagnostics`.

The failure was found through the presentation compiler: completing on a
Soundness `List` tries extension methods as candidates, and one attempt
reported a mismatch whose found type could not be pickled.
