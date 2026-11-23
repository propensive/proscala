class File extends caps.SharedCapability

def usingFile[T](op: File^ => T): T = op(File())

// The closure passed to `usingFile` reaches `Test_2` in this method's inline body, read
// from TASTy, where its result type is declared rather than inferred
inline def withFile[T](inline f: File^ => T): T = usingFile { file => f(file) }
