import ringbuf

type AllPass*[L: static[int]] = object
    x: RingBuffer[L, float32]
    y: RingBuffer[L, float32]
    delay*: uint32
    ratio*: float32

proc render*(ap: var AllPass, input: float32): float32 =
    ap.x.write(input)
    result = ap.ratio * (input - ap.y.read(ap.delay)) + ap.x.read(ap.delay)
    ap.y.write(result)
