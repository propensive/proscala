# Reproduction: exportuses

One file, compiled alone:

```
scalac -d . repro.scala
```

Without the patch (Scala 3.10.0), the `export` is rejected:

```
-- Error: repro.scala:22:13
22 |  export lib.ingest
   |             ^
   |Local any in the bound of type target leaks into capture scope of method ingest.
   |You could try to abstract the capability in a capset variable.
```

With the patch it compiles, as it does on 3.9.
