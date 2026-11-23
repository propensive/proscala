package app

import lib.*

def fill(length: Int): Unit = Array.scribe[Char](length): scribe =>
  _ => ()
