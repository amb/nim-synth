import math

proc noteToFreq*(note: float32): float32 {.inline.} = pow(2.0, (note - 69.0) / 12.0) * 440.0
