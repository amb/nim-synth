import std/bitops

type XorShift* = object
    state: int32

proc render*(self: var XorShift, offset: int32 = 0): int32 =
    # Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs"
    # https://en.wikipedia.org/wiki/Xorshift
    var x: int32 = self.state
    x += offset
    x = x xor (x shl 13)
    x = x xor (x shr 17)
    x = x xor (x shl 5)
    self.state = x
    return x
