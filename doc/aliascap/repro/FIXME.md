# FIXME: no standalone reproduction yet

The [feature doc](../aliascap.md) contains only partial fragments: the bug
needs a capability-carrying type alias defined in a module compiled *without*
capture checking, consumed from a module compiled *with* it. The doc points at
a reproduction in the Soundness repo (`rep/capturing-raises/CapturingRaises.scala`),
but a self-contained two-module reproduction (library + client, compiled
separately) still needs to be distilled into this directory and verified.
