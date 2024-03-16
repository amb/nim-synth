import std/[math, bitops]
# import ../../tools/ringbuf16

const MAX_RING_BUFFER_SIZE = 8192

type RingBuffer*[T] = object
    buffer: array[MAX_RING_BUFFER_SIZE, T]
    position: int16

proc write*[T](rb: var RingBuffer[T], sample: T) {.inline.} =
    rb.buffer[rb.position] = sample
    inc rb.position
    if rb.position >= rb.buffer.len:
        rb.position = 0

proc read*[T](rb: RingBuffer[T], rewind: uint16): T {.inline.} =
    var readPos = rb.position - rewind.int16
    while readPos < 0:
        readPos += rb.buffer.len.int16
    return rb.buffer[readPos]

# const combTaps: array[4, uint16] = [1687, 1601, 2053, 2251]
# const allpTaps: array[2, uint16] = [113, 37]

# CB: 3460, 2988, 3882, 4312
# AP: 480, 161, 46

# cf: 0.805, 0.827, 0.783, 0.764
# ap: 0.7, 0.7, 0.7

type AllPass* = object
    x: RingBuffer[float32]
    y: RingBuffer[float32]
    delay: uint16
    ratio: float32

proc run*(ap: var AllPass, input: float32): float32 =
    ap.x.write(input)
    result = ap.ratio * (input - ap.y.read(ap.delay)) + ap.x.read(ap.delay)
    ap.y.write(result)

type CombFilter* = object
    buffer: RingBuffer[float32]
    delay: uint16
    feedBack: float32

proc run*(comb: var CombFilter, input: float32): float32 =
    result = input + comb.feedBack * comb.buffer.read(comb.delay)
    comb.buffer.write(result)

type Reverb* = object
    combf: array[4, CombFilter]
    allp: array[3, AllPass]
    dry: float32

proc newReverb*(): Reverb =
    var reverb = Reverb()
    reverb.dry = 0.0

    reverb.allp[0].delay = 480
    reverb.allp[0].ratio = 0.7
    reverb.allp[1].delay = 161
    reverb.allp[1].ratio = 0.7
    reverb.allp[2].delay = 46
    reverb.allp[2].ratio = 0.7

    reverb.combf[0].delay = 3460
    reverb.combf[0].feedBack = 0.805
    reverb.combf[1].delay = 2988
    reverb.combf[1].feedBack = 0.827
    reverb.combf[2].delay = 3882
    reverb.combf[2].feedBack = 0.783
    reverb.combf[3].delay = 4312
    reverb.combf[3].feedBack = 0.764

    return reverb

proc render*(reverb: var Reverb, input: float32): float32 =
    var sample: float32 = 0

    for i in 0..3:
        sample += reverb.combf[i].run(input)

    for i in 0..2:
        sample = reverb.allp[i].run(sample)

    return sample

if isMainModule:
    echo "in main"

    var reverb = newReverb()
    var input: float32 = 0.0
    var output: float32 = 0.0

    for i in 0..10:
        input = sin(i.float32 / 100.0)
        output = reverb.render(input)
        echo output
