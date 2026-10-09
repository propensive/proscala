# Accept a declared meet of two unrelated classifiers

A class may inherit two unrelated classifier traits when another classifier among its base
classes derives from both: that classifier is their meet, and it classifies the class.

Always on: it relaxes a structural check only for hierarchies that declare a meet; a class
inheriting two unrelated classifiers with no meet is rejected as before.

## Context

Capture checking classifies a capability by the classifier traits among its base classes — those
extending `caps.Classifier`, such as `SharedCapability`, `Unscoped`, and user-defined ones. A
capture set `{any.only[C]}` admits exactly the capabilities whose classifier derives from `C`.
`CaptureOps.classifier` computes a class's classifier by folding `leastClassifier` over its
classifier base classes: of two related classifiers it keeps the more specific, and of two
unrelated ones it yields `Nothing`.

## The problem

`Setup.checkClassifiedInheritance` rejects a class if any two of its classifier base classes are
unrelated, whatever else is among them:

```scala
trait Durable extends caps.SharedCapability, caps.Classifier
trait DurableUnscoped extends Durable, caps.SharedUnscoped, caps.Classifier
// error: trait DurableUnscoped inherits two unrelated classifier traits:
//        trait SharedUnscoped and trait Durable
```

Yet the classifier computation already handles this hierarchy: `DurableUnscoped` derives from
both `Durable` and `SharedUnscoped`, so the fold keeps it at every step and never reaches
`Nothing`. The check is stricter than the semantics it guards. Soundness needs exactly this
shape: a task body may capture only `Durable` capabilities (safe to retain across a thread
boundary), and the log sinks, network access and transport observers it must use are also
level-exempt (`SharedUnscoped`). Without a meet a capability cannot be both, and a `Durable`
holder (a loop, a logger) cannot retain a level-exempt one.

## The solution

The pairwise check accepts an unrelated pair when a classifier among the class's base classes
derives from both:

```scala
val classifiers = cls.baseClasses.filter(_.isClassifiedCapabilityClass).distinct

def met(c: ClassSymbol, c1: ClassSymbol): Boolean =
  classifiers.exists(m => m.derivesFrom(c) && m.derivesFrom(c1))
```

That is precisely the condition under which the `leastClassifier` fold yields the meet rather than
`Nothing`, so the check and the computation now agree. Level exemption needs no change: the
patched tests (`isUnscopedClassifier`) already ask whether the classifier *derives from*
`SharedUnscoped`, which the meet does.

Tested by `tests/pos-custom-args/captures/classifiermeet.scala` (a meet, a holder retaining a
meet-classified capability, `only` admitting it) and `tests/neg-custom-args/captures/classifiermeet.scala`
(unrelated classifiers with no meet, and a partial meet, still rejected). The upstream
`tests/{pos,neg}-custom-args/captures` corpus (635 files) behaves identically with and without
the patch.
