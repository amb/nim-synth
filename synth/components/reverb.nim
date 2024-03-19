import std/[math, bitops]
import ringbuf, allpass, combfilter

const rAllPasses = [480.0, 0.7, 161.0, 0.7, 46.0, 0.7]
const rCombFilters = [3460.0, 0.805, 2988.0, 0.827, 3882.0, 0.783, 4312.0, 0.764]

type Reverb* = object
    combf: array[4, CombFilter[8192]]
    allp: array[3, AllPass[512]]
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

    for i in 0..2:
        sample = reverb.allp[i].render(sample)

    let cval = sample
    sample = 0.0
    for i in 0..3:
        sample += reverb.combf[i].render(cval)
    sample *= 0.25

    return reverb.dry * input + (1.0 - reverb.dry) * sample

proc renderStereo*(reverb: var Reverb, input: float32): (float32, float32) =
    # https://ccrma.stanford.edu/~jos/pasp/Schroeder_Reverberators.html
    var sample: float32 = input

    # Allpass block
    for i in 0..2:
        sample = reverb.allp[i].render(sample)

    # Comb filter block
    let c1 = reverb.combf[0].render(sample)
    let c2 = reverb.combf[1].render(sample)
    let c3 = reverb.combf[2].render(sample)
    let c4 = reverb.combf[3].render(sample)

    # Mixing matrix
    let s1 = c1 + c3
    let s2 = c2 + c4

    let oa = s1 + s2
    let od = s1 - s2
    # let ob = -oa
    # let oc = -od

    # Stereo out
    var left = oa
    var right = od

    left = reverb.dry * input + (1.0 - reverb.dry) * left
    right = reverb.dry * input + (1.0 - reverb.dry) * right
    return (left, right)

if isMainModule:
    echo "Reverb test"

    var reverb = newReverb()
    var input: float32 = 0.0
    var output: float32 = 0.0

    for i in 0..10:
        input = sin(i.float32 / 10.0)
        output = reverb.render(input)
        echo output
