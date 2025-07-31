import ringbuf

type CombFilter*[L: static[int]] = object
    buffer: RingBuffer[L, float32]
    delay*: uint32
    feedBack*: float32
    damping*: float32
    filterStore: float32

proc render*(comb: var CombFilter, input: float32): float32 =
    # TODO: possible un-denormalize macro etc. if performance issues
    comb.filterStore = comb.filterStore * comb.damping + comb.buffer.read(comb.delay) * (1.0'f32 - comb.damping)
    result = input + comb.feedBack * comb.filterStore
    comb.buffer.write(result)
