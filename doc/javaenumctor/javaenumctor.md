# Give java.lang.Enum its no-argument constructor whichever root loads it

Lets an enum extend `java.lang.Enum[X]` without constructor arguments even where a static member of `java.lang.Enum`, such as `valueOf`, was resolved first.

## Context

An enum can be made a Java enum by extending `java.lang.Enum`:

```scala
enum Color extends java.lang.Enum[Color]:
  case Red, Green
```

It names no arguments for the parent, although `java.lang.Enum` has only one
constructor, `protected Enum(String name, int ordinal)`: a later phase,
`CompleteJavaEnums`, passes each case's name and ordinal. To let the parent call
typecheck before then, `Definitions` treats `java.lang.Enum` specially. It
replaces the loader of the class with one which, after reading the class file,
strips the two parameters from the constructor and enters a copy that keeps
them, so that both `Enum[X]` and `Enum[X](name, ordinal)` are accepted.

A Java class file holds a class and its static members, and the compiler models
the statics as the members of a companion object. So one class file defines two
symbols, the class and the companion's module class, and both are given the same
loader. Whichever of them is completed first reads the class file and fills both
in. But only the class was given the replaced loader.

## Reproduction

[`repro/`](repro/). One file, with no flags, which calls a static member of
`java.lang.Enum` before the enum is typed:

```scala
object Lookup:
  def green: Color = java.lang.Enum.valueOf(classOf[Color], "Green")

enum Color extends java.lang.Enum[Color]:
  case Red, Green
```

```
-- Error:
  |enum Color extends java.lang.Enum[Color]:
  |                   ^^^^^^^^^^^^^^^^^^^^^
  |not enough arguments for constructor Enum in class Enum: (x$0: String, x$1: Int): Enum[Color]
```

`java.lang.Enum.valueOf` completes the companion first. The class file is read
with the companion's loader, the original one, and the class is left with only
its two-parameter constructor. With the two definitions the other way round, the
enum's parent completes the class first, and the file compiles.

From source this needs an unusual order. Recompiling from TASTy, it is the
usual one: a tool which reads units as it finds that it needs them reads the
user of an enum before the enum, and the enum's TASTy then fails to be read,
with `wrong number of arguments … expected: 2, found: 0`.

## Solution

The adjustment now runs whichever root is completed first
(`core/Definitions.scala`). It moves from `complete` into `doComplete`, the
method that reads the class file for both roots, and the module class is given
the new loader too, as a proxy that keeps its declarations and source module:

```scala
cls.info = loader
val moduleClass = cls.scalacLinkedClass
moduleClass.infoOrCompleter match
  case moduleCompleter: SymbolLoader =>
    moduleClass.info = loader.proxy
      .withDecls(moduleCompleter.decls)
      .withSourceModule(moduleCompleter.sourceModule)
  case _ =>
```

A proxy forwards `doComplete` to the loader it was made from, so completing the
module class runs the overridden method, which reads the file once and adjusts
the class's constructors. This is how `SymbolLoaders.enterModule` makes the
module class's loader in the first place.

The patch is always on: it only accepts a program that was rejected.

## Upstream

Upstream 3.10.0 behaves the same, from source and from TASTy. Worth reporting
upstream with the reproduction.

`tests/pos/javaenum-static-first.scala` holds the one-file reproduction.
