# FIXME: no standalone reproduction yet

The [feature doc](../lazycycle.md) shows the F-bounded shape involved, but the
StackOverflow only fires when a cyclic `LazyRef` graph is forced — which needs
a macro-induced compilation suspension in addition to the shown code. A
self-contained multi-file reproduction still needs to be distilled and
verified.
