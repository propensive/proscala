package app

import language.experimental.captureChecking

class Terrain
abstract class Reader(val view: Terrain^) { type Topic }

def same(reader: Reader^): (Reader { type Topic = reader.Topic })^{reader} = reader

def refined(reader: Reader^)(same: (Reader { type Topic = reader.Topic })^): Int = 0
def argument(reader: Reader^): Int = refined(reader)(reader)
