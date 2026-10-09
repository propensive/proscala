# Reproduction: classifiermeet

```
scalac -experimental -Ycc-new -language:experimental.separationChecking meet.scala
```

`meet.scala` declares a classifier `Both` deriving from two unrelated classifiers, `Durable` and
`Scoped`, and classifies a capability with it. On the unpatched compiler every class in the
hierarchy is rejected:

```
trait Both inherits two unrelated classifier traits: trait Scoped and trait Durable
trait Sink inherits two unrelated classifier traits: trait Scoped and trait Durable
```

With the patch it compiles: `Both` is the least classifier of `Sink`, a `Durable` holder (`Loop`)
may retain a `Sink`, and a body typed `only[Durable]` admits it.
