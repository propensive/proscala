import language.experimental.captureChecking
import language.experimental.separationChecking

import Backends.backend

def test = summon[Backend]
