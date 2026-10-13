# Do not recheck the escaping uses of an export forwarder

Lets an extension method whose type parameter is bounded by a capability class be exported again, by not rechecking the uses inside the synthesized export forwarder.

Always on: it only turns programs that upstream rejects into accepted ones.

## Context

An `export` clause synthesizes a *forwarder* for each exported method: a method
with the same signature whose body calls the original, passing its own
parameters, and its own type parameters as type arguments.

Capture checking checks that a method body does not use the root capability of a
parameter's declared type: a parameter `x: C^` may be used, but the `any` its
type mentions stands for whatever the caller's argument captures, and must not
leak into the method's scope. On 3.10 a type parameter bounded by a capability
class counts too: `target <: Intake[medium]`, where `Intake` is a capability, has
the bound `Intake[medium]^`, with a root of its own. When the forwarder passes
`target` on as a type argument, the bound's root counts as used, and the check
reports it as leaking — although the forwarded method declares exactly the same
bound and admits the argument.

## Reproducing it

```scala
package lib:
  trait Intake[medium] extends caps.ExclusiveCapability, caps.Stateful:
    type Transport
    update def finish(): Unit
  trait Stream[medium] extends caps.ExclusiveCapability, caps.Stateful:
    type Transport

  extension [medium, transport, target <: (Intake[medium] { type Transport = transport })]
    (consume intake: target^)
    def ingest(consume stream: (Stream[medium] { type Transport = transport })^): target^ =
      intake.finish()
      intake

package umbrella:
  export lib.ingest
```

Scala 3.10.0 rejects the `export`:

```
Local any in the bound of type target leaks into capture scope of method ingest.
You could try to abstract the capability in a capset variable.
```

3.9 accepts it. This is Soundness's `zephyrine.ingest`, which the `soundness`
package re-exports: `Gather().ingest(bytes.stream).data` returns the intake, typed
as the caller's own class, once the stream is exhausted. Abstracting the bound
over a capture-set parameter, as the message suggests, satisfies 3.10 but breaks
every caller on 3.9, where the result then mentions the consumed intake; a
hand-written forwarder is rejected by both.

## The solution

An export forwarder adds nothing to check: it only passes its parameters on to a
method that admits them, and that method's own body was checked. So
`checkEscapingUses` skips the uses recorded inside one:

```scala
for (tree, uses, env) <- useInfos if !env.owner.is(Exported) do
```

Everything else about a forwarder is checked as before (its signature is the
forwarded method's, and calls to it are checked against that), and a
hand-written forwarder is still checked in full. The patch's test is
`pos-custom-args/captures/exportuses.scala`, and the outcome of every other test
in `tests/{neg,pos}-custom-args/captures` is unchanged.
