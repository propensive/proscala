# Reproduction: overridevars

Compile `repro.scala`, on any platform; the capture-checking language import
is the whole configuration:

```
scalac repro.scala
```

Without the patch, the class in the expansion of `derived` is rejected:

```
error overriding method text in trait Inspectable of type (value: Self): String;
  method text of type (arg: Point^'s1): String has incompatible type
```

The type argument `value` is inferred, so its occurrence in the parameter type
of `text` and its occurrence in the alias of `Self` each get a capture set
variable, and the override check, made with frozen constraints, cannot relate
the two.

With the patch, the file compiles (with upstream's warning that the anonymous
class is duplicated at each inline site). Passing the type argument explicitly,
`derived[Point](point)`, compiles either way: an explicit argument gets no
variables.

[`../repro-sam`](../repro-sam) is the form the fault was reported in, where the
class is made by the compiler for a lambda under `-scalajs`.
