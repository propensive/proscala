package app

import language.experimental.captureChecking
import language.experimental.separationChecking
import lib.*

type Bytes = Frozen[Byte]^{}
def first(nested: Frozen[Bytes]^{}): Bytes = nested.read(0)
