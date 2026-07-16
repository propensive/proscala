# Lazy resolution of permitted subclasses in classfile parsing

Defers resolution of a Java sealed class's permitted subclasses until the corresponding `@Child` annotation is actually forced, breaking spurious completion cycles when parsing classfiles.

## Context

When the Scala 3 compiler compiles against pre-built code — the JDK itself, or library jars — it does not have source files for those classes. Instead, `ClassfileParser` reads the JVM `.class` files and reconstructs compiler symbols from the bytecode metadata. This happens *lazily*: a symbol is a cheap placeholder until something asks for its members or parents, at which point its *completer* runs and parses the classfile. Completion of one class routinely triggers completion of others (its superclasses, the types in its signatures), so the compiler must be careful that these chains never loop back on themselves.

One piece of classfile metadata is the `PermittedSubclasses` attribute, introduced by JEP 409 (sealed classes, Java 17). A sealed Java class or interface lists exactly which classes may extend it. Scala's own `sealed` traits compile to the same attribute. The Scala compiler needs this information — most importantly for exhaustivity checking of pattern matches — and records it by attaching one `scala.annotation.internal.Child[C]` annotation per permitted subclass `C` to the sealed class's symbol.

## The problem

The parser resolved each permitted subclass *eagerly*, calling `getClassSymbol(child.name)` while the sealed class's own completion was still in progress. Resolving a class symbol can force completion of that class, whose signature can in turn refer back to other sealed interfaces in the same library — and suddenly the completion chain forms a cycle.

This is not hypothetical. The JDK 25 `java.lang.classfile` API is a dense web of sealed interfaces: `MethodModel` permits the implementation class `BufferedMethodBuilder$Model`, and `BufferedMethodBuilder`'s parents lead back to the sealed `MethodInfo`. Merely referring to these types from Scala code:

```scala
import java.lang.classfile.*

def inspect(m: MethodModel): Unit = ()
```

fails with:

```
Cyclic reference involving class BufferedMethodBuilder
```

(reported upstream as scala/scala3#25451). No user code is wrong; the compiler simply forces the child class at the worst possible moment.

## The solution

The child symbol does not need to exist during completion — it is only needed when the `@Child` annotation's *tree* is inspected, e.g. by exhaustivity checking, which happens well after all the relevant completions have settled. The compiler already has a mechanism for this: `Annotation.deferredSymAndTree` takes the annotation tree as a by-name argument that is evaluated only on first access.

The patch moves the `getClassSymbol(child.name)` call from outside the deferred annotation (evaluated eagerly, mid-completion) to inside it (evaluated lazily, on demand). The set of permitted subclass *names* is still recorded immediately, so nothing is lost; only the symbol lookup is postponed past the danger zone.

## Code

The whole change is in `compiler/src/dotty/tools/dotc/core/classfile/ClassfileParser.scala`, in `AttributeCompleter.complete`:

```scala
// Before: cls resolved eagerly, during the sealed class's completion
permittedSubclasses.foreach { child =>
  val cls = getClassSymbol(child.name)
  sym.addAnnotation(Annotation.deferredSymAndTree(defn.ChildAnnot)(
    New(defn.ChildAnnot.typeRef.appliedTo(cls.owner.thisType.select(cls.name, cls)), Nil)
      .withSpan(NoSpan)))
}
```

```scala
// After: cls resolved inside the by-name tree, when the annotation is first forced
permittedSubclasses.foreach { child =>
  sym.addAnnotation(Annotation.deferredSymAndTree(defn.ChildAnnot) {
    val cls = getClassSymbol(child.name)
    New(defn.ChildAnnot.typeRef.appliedTo(cls.owner.thisType.select(cls.name, cls)), Nil)
      .withSpan(NoSpan)
  })
}
```

The tree construction is unchanged; only its evaluation time moves.

## Relevance to Soundness

Soundness's *Mandible* module is a bytecode-inspection library built directly on the JDK 25 `java.lang.classfile` API — exactly the sealed-interface web that triggers the cycle. `lib/mandible/src/core/mandible.Classfile.scala` wraps `jlc.MethodModel` and pattern-matches over `jlc.CodeElement` values:

```scala
class Method(model: jlc.MethodModel):
  ...
  elements.foreach:
    case instr: jlc.Instruction   => offset += instr.sizeInBytes
    case target: jlci.LabelTarget => builder += target.label.nn -> offset
    case _                        => ()
```

Both referencing `MethodModel` and exhaustivity-checking matches over the sealed `CodeElement` hierarchy require the compiler to parse these JDK classfiles and their `PermittedSubclasses` attributes; without this patch, compiling Mandible fails with the cyclic-reference error above.
