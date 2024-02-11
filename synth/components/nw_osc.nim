import std/[math, random, sugar]
import ../network

type Oscillator* = ref object of NetworkDevice
    freq, amp, phase: int

var sin_wt*: array[65536, float32]
for i in 0..65535:
    sin_wt[i] = sin(i.float32 / 65536.0 * math.PI * 2.0).float32

proc publish*(nw: var SynthNetwork, osc: Oscillator) =
    result.freq = nw.addInput(0.0, "frequency")
    result.amp = nw.addInput(1.0, "amplitude")
    result.phase = nw.addInput(0.0, "phase")
    # Output is always only 1 float32

proc process*(osc: Oscillator, step: float32, inputs: openArray[float32]): float32 =
    let freq = inputs[osc.freq]
    let amp = inputs[osc.amp]
    let phase = inputs[osc.phase]
    
    result = wt[(phase * 65536.0).uint16]
    phase += step * freq
    phase -= max(0, phase.int).float32
    phase += -(min(0.0, phase - 1.0).int).float32
    result *= amp
