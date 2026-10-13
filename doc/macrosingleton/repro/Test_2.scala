package repro

def use: Optional[String] = macros.pick(false)

@main def Test: Unit = assert(use == null)
