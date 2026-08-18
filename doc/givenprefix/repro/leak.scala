package other
import minirepro.*
import minirepro.consConstructor

object Leak:
  val leak = (2 :: Nul).length  // member of the underlying sci.List
