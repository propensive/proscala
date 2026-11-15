import language.experimental.captureChecking

// Kept a singleton, the spliced value is still checked: it captures `io`,
// which the pure bound of `calcPure`'s type parameter does not allow.
def g(io: Object^, xs: List[Pure^{io}]) = xs.map: pure =>
  goPure[pure.type](pure)
