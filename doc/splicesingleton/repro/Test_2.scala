import language.experimental.captureChecking

def f(io: Object^, xs: List[Path^{io}]) = xs.map: path =>
  go[path.type](path)
