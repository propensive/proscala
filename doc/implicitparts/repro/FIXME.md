# No self-contained reproduction yet

The crash needs an implicit search whose type, after `wildApprox`, still reaches
an uninstantiated type parameter through the info of a term reference in it. In
Soundness that is an inline match's given search (`summonFrom`) whose type
mentions an inline `this`-proxy, typed while an enclosing call's type variables
were still open. The in-tree reproduction is exoskeleton's `rig` module, on an
unpatched 3.10 tree:

    mill exoskeleton.rig.compile

crashes on its use of `state/next` (serpentine's transparent `/`, inside a
`fuse` within `mitigate` or `protect`) with

    java.lang.AssertionError: assertion failed: `wildApprox` failed to remove uninstantiated value

Stock Scala 3.10.0 crashes the same way; 3.9 compiles the module. Extracting a
case without Soundness's inline machinery is still to do.
