# Reproduction: overridevars, for a lambda under `-scalajs`

Compile `repro.scala` **to Scala.js**:

```
scalac -scalajs repro.scala
```

The instance is a lambda, converted to the SAM type `Inspectable`. On the JVM
it stays a closure and the file compiles, with or without the patch. Under
`-scalajs` an ordinary trait is not a SAM type of the platform, so `ExpandSAMs`
makes an anonymous class of the lambda before capture checking, and without
the patch that class is rejected, as the one written out in
[`../repro`](../repro) is on every platform:

```
error overriding method text in trait Inspectable of type (value: Self): String;
  method text of type (arg: Point^'s1): String has incompatible type
```

With the patch, the file compiles to Scala.js too.
