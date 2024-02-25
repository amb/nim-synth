import std/[math, random, sugar]
import ../network

type Oscillator* = ref object of NetworkDevice
    freq, amp, phase: ptr float32

var sin_wt*: array[65536, float32]
for i in 0..65535:
    sin_wt[i] = sin(i.float32 / 65536.0 * math.PI * 2.0).float32

proc publish*(nw: var SynthNetwork): Oscillator =
    result.freq = nw.addInput(0.0, "frequency")
    result.amp = nw.addInput(1.0, "amplitude")
    result.phase = nw.addInput(0.0, "phase")
    # Output is always only 1 float32

proc process*(osc: Oscillator): float32 =
    result = wt[(phase[] * 65536.0).uint16]
    phase += freq[]
    phase -= splitDecimal(phase).intpart
    result *= amp

proc setFreq*(osc: Oscillator, freq, sampleRate: float32) =
    # Get the phase increment for the given frequency
    osc.freq[] = 65536 * freq / sampleRate
