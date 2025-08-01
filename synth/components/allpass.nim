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

# type AllPass*[L: static[int]] = object
#     buffer: RingBuffer[L, float32]
#     delay*: uint32
#     ratio*: float32

# proc render*(ap: var AllPass, input: float32): float32 =
#     let delayed = ap.buffer.read(ap.delay)
#     let output = ap.ratio * (input - delayed) + delayed
#     ap.buffer.write(output)
#     result = output
