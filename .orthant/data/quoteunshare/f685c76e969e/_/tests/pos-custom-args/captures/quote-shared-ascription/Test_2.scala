def first(payload: String)(using Tactic): Request =
  val make: () => Request = () => submit(payload)
  make()

def second(payload: String)(using Tactic): Request = submit(payload)
