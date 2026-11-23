// A closure's proxy keeps the bound its parameter declares: the argument is checked
// against the proxy alone, so capture sets are inferred only where the parameter's
// function type may capture anything.

inline def runPure(action: () -> Unit): Unit = action()
inline def runOnly(io: Object^)(action: () ->{io} Unit): Unit = action()

def test(io: Object^, other: Object^): Unit =
  runPure(() => println(io))         // error
  runOnly(io)(() => println(other))  // error
  runOnly(io)(() => println(io))

class Res extends caps.SharedCapability
inline def useOnly(io: Res)(x: Object^{io}): Unit = println(x)
inline def usePure(x: Object^{}): Unit = println(x)

def args(io: Res, other: Res, o: Object^{other}): Unit =
  useOnly(io)(identity(o))  // error
  usePure(identity(o))      // error
