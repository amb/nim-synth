import ringbuf

type CombFilter*[L: static[int]] = object
    buffer: RingBuffer[L, float32]
    delay*: uint32
    feedBack*: float32

proc render*(comb: var CombFilter, input: float32): float32 =
    result = input + comb.feedBack * comb.buffer.read(comb.delay)
    comb.buffer.write(result)
