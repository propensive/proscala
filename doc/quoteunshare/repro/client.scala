def first(value: Int): Int =
  val make: () => Int = () => serve(value)
  make()

def second(value: Int): Int = serve(value)
def third(value: Int): Int = serve(value)
