# macroloader

Resolve a macro's classes from the compilation classpath, not from the loader of whatever host embeds the compiler.

Enabled by `-Zisolated-macros`. With the flag absent, the compiler builds the
macro class loader exactly as upstream does.

## Context

When the compiler expands a macro it has to *run* the macro's implementation,
so it needs a class loader. Upstream's `MacroClassLoader.makeMacroClassLoader`
builds one over the compilation classpath and the output directory, with the
loader that loaded the compiler itself as its parent:

```scala
new java.net.URLClassLoader((urls ++ out.toList).toArray, getClass.getClassLoader)
```

Java class loaders delegate *parent first*: a class is looked up in the parent
before the loader's own URLs are tried. For a standalone `scalac` that is
harmless, because the compiler's loader holds only the compiler and its own
dependencies. But a host that embeds the compiler — a build tool with warm
compiler sessions, an IDE, a script runner — loads it beside the host's *own*
libraries, and every class the host also carries is then resolved from the
host's copy instead of from the compilation classpath. A macro loaded from the
session is linked against the host's version of its dependencies, and whenever
the two versions differ it fails with a linkage error.

This was observed in [fuel](https://github.com/propensive/fuel), which bundles
a Soundness build to run itself. Compiling a project against a newer Soundness
in which `murmuration.Traversable.traverse` had changed its result type,
xenophile's `Interface` macro — correct against the session classpath — was
linked against fuel's older `murmuration`:

```
Exception occurred while executing macro expansion.
java.lang.NoSuchMethodError: 'murmuration.Iterator murmuration.Traversable.traverse(java.lang.Object)'
	at xenophile.TypescriptDialect$.project(xenophile.TypescriptDialect.scala:63)
```

Any macro that touches a library the host also bundles is exposed, as soon as
the versions drift. The key of the context property holding the loader is
private, and `MacroClassLoader.init` always calls `makeMacroClassLoader`, so a
host has no supported way to supply a loader of its own.

## Reproducing it

The reproduction in [`repro/`](repro/README.md) stands in for the host with a
second copy of a library on the compiler's classpath. A library:

```scala
package repro.lib
object Lib:
  def version: String = "session"   // the host's copy says "host"
```

a macro that reads it while expanding:

```scala
object Macro:
  inline def version: String = ${ versionImpl }
  def versionImpl(using Quotes): Expr[String] = Expr(repro.lib.Lib.version)
```

and a program printing `Macro.version`. The program is compiled by launching
the compiler with the host's copy beside its jars and only the session copy on
`-cp`:

```
java -cp "hostcp:$SCALA_HOME/lib/*:$SCALA_HOME/deps/*" dotty.tools.dotc.Main \
  -cp "session:macro:$SCALA_HOME/lib/*" -d out Use.scala
```

Upstream, and Proscala without the flag, print `host`: the parent won. The same
compilation under a plain `scalac` prints `session`, which is the behaviour a
macro author can reason about.

## The solution

With `-Zisolated-macros`, the parent of the macro loader is an
`IsolatingLoader` that shares with the compiler's loader only what a macro
*must* share with the compiler, and sends everything else to the platform
class loader:

```scala
private class IsolatingLoader(compiler: ClassLoader)
    extends ClassLoader(ClassLoader.getPlatformClassLoader) {
  private def shared(name: String, sep: Char): Boolean =
    name.startsWith(s"scala$sep") || name.startsWith(s"dotty$sep")

  override def loadClass(name: String, resolve: Boolean): Class[?] =
    if shared(name, '.') then compiler.loadClass(name) else super.loadClass(name, resolve)

  override def getResource(name: String): java.net.URL | Null =
    if shared(name, '/') then compiler.getResource(name) else super.getResource(name)

  override def getResources(name: String): java.util.Enumeration[java.net.URL] =
    if shared(name, '/') then compiler.getResources(name) else super.getResources(name)
}
```

Two names must stay shared. `scala.` covers the standard library and the quotes
API: a macro's `Quotes` has to be the very class the compiler instantiates, so
the compiler's standard library is the one a macro sees even if the session's
differs — the constraint upstream already imposes. `dotty.` is the compiler
itself. Everything else falls through to the platform loader, which holds the
whole JDK (not only `java.*`, but `org.w3c.dom`, `com.sun.*` and the rest), and
a name the platform loader does not know is refused — which makes the child
`URLClassLoader` look it up on the compilation classpath and the output
directory, as it would in a standalone `scalac`. Resources are routed the same
way, since the macro loader is also the thread's context class loader while a
macro runs (`ServiceLoader` and friends go through it).

The flag exists because the isolation is also a restriction: a macro that
reached one of the compiler's own dependencies (jline, guava, `xsbti`, …)
through the parent loader without declaring it will no longer find it. Upstream
lets such a macro expand by accident of what the compiler happens to bundle;
`-Zisolated-macros` is the choice to stop relying on that. Hosts embedding the
compiler pass the flag; a build that only runs `scalac` gains nothing from it.

No upstream-style test under `tests/` can express a host class loader, so the
reproduction is the patch's test. The patch is held in one version per line of
upstream history, differing only in how the output directory is turned into a
URL.
