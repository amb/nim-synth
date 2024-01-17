import std/[math, random]

type ADSR* = object
    attack*: float32
    decay*: float32
    sustain*: float32
    release*: float32
    finished*: bool
    released: bool
    previous: float32
    previousProgress: float32
    progress: float32

proc render*(adsr: var ADSR, step: float32): float32 =
    if adsr.finished:
        return 0.0

    if not adsr.released:
        # Attack envelope
        if adsr.progress < adsr.attack:
            result = adsr.progress / adsr.attack
            adsr.progress += step
        # Decay envelope
        elif adsr.progress < adsr.attack + adsr.decay:
            result = 1.0 - (adsr.progress - adsr.attack) / adsr.decay * (1.0 - adsr.sustain)
            adsr.progress += step
        # Sustain
        else:
            result = adsr.sustain

        adsr.previous = result
        adsr.previousProgress = adsr.progress

    # Release envelope
    else:
        result = adsr.previous - (adsr.progress - adsr.previousProgress) / adsr.release * adsr.previous
        adsr.progress += step

        # Finished
        if adsr.progress >= adsr.previousProgress + adsr.release:
            adsr.finished = true

type Oscillator* = object
    frequency*: float32
    amplitude*: float32
    phase*: float32
    feedback*: float32

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

proc render*(osc: var Oscillator, osc_func: proc (phase: float32): float32, step: float32): float32 =
    result = osc_func(osc.phase)
    result *= osc.amplitude
    osc.phase += osc.frequency * step
    osc.phase -= max(0, osc.phase.int).float32
    osc.phase += -(min(0.0, osc.phase - 1.0).int).float32

proc render_fm*(osc: var Oscillator, osc_func: proc (phase: float32): float32, step: float32, fm: float32): float32 =
    result = osc_func(osc.phase)
    result *= osc.amplitude
    osc.phase += (osc.frequency * (1.0 + fm)) * step
    osc.phase -= max(0, osc.phase.int).float32
    osc.phase += -(min(0.0, osc.phase - 1.0).int).float32

type AudioSynth* = object
    # IMPORTANT: keep this non-variable size
    adsr*: array[2, ADSR]
    osc*: array[2, Oscillator]
    finished*: bool
    oscRatio*: float32
    runtime: uint64
    sampleRate: float32
    sampleTime: float32

proc newAudioSynth*(frequency, amplitude: float32): AudioSynth =
    # Synth defaults defined here
    result = AudioSynth()

    result.oscRatio = 0.5

    result.adsr[0] = ADSR(attack: 0.002, decay: 0.1, sustain: 0.5, release: 0.2)
    result.osc[0] = Oscillator(frequency: frequency, amplitude: amplitude, feedback: 0.0)
    
    result.adsr[1] = ADSR(attack: 0.01, decay: 0.01, sustain: 1.0, release: 0.01)
    result.osc[1] = Oscillator(frequency: frequency * result.oscRatio, amplitude: 1.0, feedback: 0.0)
    
    result.sampleRate = 48000.0
    result.sampleTime = 1.0 / result.sampleRate

proc spawnFrom*(synth: AudioSynth): AudioSynth =
    result = synth
    result.finished = false
    result.runtime = 0

proc setNote*(synth: var AudioSynth, frequency, amplitude: float32) =
    synth.osc[0].frequency = frequency
    synth.osc[0].amplitude = amplitude
    synth.osc[1].frequency = frequency * synth.oscRatio

proc render*(synth: var AudioSynth): float32 =
    if synth.finished:
        return 0.0

    let st = synth.sampleTime
    var osc1 = synth.osc[1].render(osc_sin, st)
    osc1 *= synth.adsr[1].render(st)
    result = synth.osc[0].render_fm(osc_saw, st, osc1)
    result *= synth.adsr[0].render(st)
    # result = osc1
    
    inc synth.runtime
    if synth.adsr[0].finished:
        synth.finished = true

proc release*(synth: var AudioSynth) =
    synth.adsr[0].released = true
