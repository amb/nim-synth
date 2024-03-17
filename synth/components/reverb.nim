{.experimental: "callOperator".}

import std/[math, bitops]

type RingBuffer[L: static[int], T] = object
    buffer: array[L, T]
    position: int16

proc write[L, T](rb: var RingBuffer[L, T], sample: T) {.inline.} =
    rb.buffer[rb.position] = sample
    inc rb.position
    if rb.position >= rb.buffer.len:
        rb.position = 0

proc read[L, T](rb: RingBuffer[L, T], rewind: uint16): T {.inline.} =
    var readPos = rb.position - rewind.int16
    while readPos < 0:
        readPos += rb.buffer.len.int16
    return rb.buffer[readPos]

type AllPass* = object
    x: RingBuffer[512, float32]
    y: RingBuffer[512, float32]
    delay: uint16
    ratio: float32

proc `()`*(ap: var AllPass, input: float32): float32 =
    ap.x.write(input)
    result = ap.ratio * (input - ap.y.read(ap.delay)) + ap.x.read(ap.delay)
    ap.y.write(result)

type CombFilter* = object
    buffer: RingBuffer[8192, float32]
    delay: uint16
    feedBack: float32

proc `()`*(comb: var CombFilter, input: float32): float32 =
    result = input + comb.feedBack * comb.buffer.read(comb.delay)
    comb.buffer.write(result)

const rAllPasses = [480.0, 0.7, 161.0, 0.7, 46.0, 0.7]
const rCombFilters = [3460.0, 0.805, 2988.0, 0.827, 3882.0, 0.783, 4312.0, 0.764]

type Reverb* = object
    combf: array[4, CombFilter]
    allp: array[3, AllPass]
    dry: float32

proc newReverb*(): Reverb =
    var reverb = Reverb()
    reverb.dry = 0.5

    for i in 0..2:
        reverb.allp[i].delay = rAllPasses[i * 2].uint16
        reverb.allp[i].ratio = rAllPasses[i * 2 + 1]

    for i in 0..3:
        reverb.combf[i].delay = rCombFilters[i * 2].uint16
        reverb.combf[i].feedBack = rCombFilters[i * 2 + 1]

    return reverb

proc render*(reverb: var Reverb, input: float32): float32 =
    var sample: float32 = input

    for i in 0..3:
        sample += reverb.combf[i](input)
    sample *= 0.25

    for i in 0..2:
        sample = reverb.allp[i](sample)

    return reverb.dry * input + (1.0 - reverb.dry) * sample

if isMainModule:
    echo "Reverb test"

    var reverb = newReverb()
    var input: float32 = 0.0
    var output: float32 = 0.0

    for i in 0..10:
        input = sin(i.float32 / 10.0)
        output = reverb.render(input)
        echo output
