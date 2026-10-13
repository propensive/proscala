import language.experimental.captureChecking

class File extends caps.SharedCapability

def usingFile[T](op: File^ => T): T = op(File())

inline def withFile[T](inline f: File^ => T): T = usingFile { file => f(file) }
