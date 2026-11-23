// A singleton argument spliced by a macro is wrapped in an `Inlined` node, which is
// adapted after the expression inside it and takes its type, already boxed as
// `x.type^{x}`. It must not then be widened to the declared type of `x`.

def f(io: Object^, xs: List[Path^{io}]) = xs.map: path =>
  go[path.type](path)

def g(io: Object^, path: Path^{io}) = go[path.type](path)
