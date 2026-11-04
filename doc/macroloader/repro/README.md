# Reproduction: macroloader

A library, a macro that reads it at expansion time, and a program using the
macro — plus a second copy of the library standing in for the one an embedding
host carries beside the compiler.

```
scalac -d session Lib.scala              # Lib.version == "session"
scalac -d hostcp  host/Lib.scala         # Lib.version == "host"
scalac -cp session -d macro Macro.scala
```

`Use.scala` is then compiled with `hostcp/` on the **compiler's** classpath, as
a host that loads the compiler alongside its own libraries would have it, and
only `session/` and `macro/` on the compilation classpath:

```
java -cp "hostcp:$SCALA_HOME/lib/*:$SCALA_HOME/deps/*" dotty.tools.dotc.Main \
  -cp "session:macro:$SCALA_HOME/lib/*" -d out Use.scala
java -cp "out:$SCALA_HOME/lib/*" repro.run
```

Without the patch (or without the flag) this prints `host`: the macro class
loader's parent is the compiler's loader, and parent-first delegation finds
the host's `repro.lib.Lib` before the session's. With the patch and
`-Zisolated-macros` it prints `session`, as the same compilation does under a
standalone `scalac`.
