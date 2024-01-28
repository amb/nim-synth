import std/[math, random]

type Oscillator* = object
    frequency*: float32
    amplitude*: float32
    phase*: float32
    feedback*: float32
    previous: float32

proc osc_sin*(phase: float32): float32 = sin(phase * math.PI * 2.0)
proc osc_saw*(phase: float32): float32 = phase * 2.0 - 1.0
proc osc_sqr*(phase: float32): float32 = (if phase < 0.5: 1.0 else: -1.0)

proc osc_harmonic_sqr*(phase: float32, numHarmonics: int): float32 =
    for i in 1..numHarmonics:
        let n = i.float32 * 2.0 - 1.0
        result += osc_sin(phase * n) / n
    result *= 4.0 / math.PI

proc osc_hsqr9*(phase: float32): float32 = osc_harmonic_sqr(phase, 19)

proc osc_harmonic_saw*(phase: float32, numHarmonics: int): float32 =
    for i in 1..numHarmonics:
        let n = i.float32
        result += pow(-1, n) * osc_sin(phase * n) / n

proc osc_hsaw9*(phase: float32): float32 = osc_harmonic_saw(phase, 19)

proc render*(osc: var Oscillator, osc_func: proc (phase: float32): float32, step: float32, fm: float32): float32 =
    result = osc_func(osc.phase + osc.feedback * osc.previous)
    osc.previous = result
    result *= osc.amplitude
    osc.phase += (step * osc.frequency * (1.0 + fm))
    osc.phase -= max(0, osc.phase.int).float32
    osc.phase += -(min(0.0, osc.phase - 1.0).int).float32