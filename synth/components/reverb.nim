import std/[math]
import ../../tools/ringbuf16

# const combTaps: array[4, uint16] = [107, 113, 163, 331]
const combTaps: array[4, uint16] = [1687, 1601, 2053, 2251]
const allpTaps: array[2, uint16] = [113, 37]

type Reverb* = object
    buffer: RingBuffer16[float32]
    dryBuffer: RingBuffer16[float32]
    feedForward: float32
    feedBack: float32
    dry: float32

proc newReverb*(): Reverb =
    var reverb = Reverb()
    reverb.feedBack = 0.9
    reverb.feedForward = 1.0 - reverb.feedBack
    reverb.dry = 0.05
    return reverb

proc render*(reverb: var Reverb, input: float32): float32 =
    var sample: float32 = 0

    # Parallel comb filters
    # Is this actually a Householder reflection?
    for ti, t in combTaps:
        sample += reverb.feedForward * input + reverb.feedBack * reverb.buffer.read(t)
    sample *= 0.25
    reverb.buffer.write(sample)

    # Serial all-pass filters
    # let apm = 0.2
    # for ti, t in allpTaps:
    #     sample = apm * sample + reverb.dryBuffer.read(t) - apm * reverb.buffer.read(t)

    # Write it out
    reverb.dryBuffer.write(input)
    return reverb.dry * input + (1 - reverb.dry) * sample
