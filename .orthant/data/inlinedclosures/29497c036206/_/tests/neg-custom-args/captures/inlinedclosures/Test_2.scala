//> using options -Zcheck-inlined-closures

def test = withFile(file => () => file) // error // error
