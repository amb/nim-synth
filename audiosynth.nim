import std/[math, random]
import components/[adsr, osc, impfilter]

type AudioSynth* = object
    # IMPORTANT: keep this non-variable size
    adsr*: array[2, ADSR]
    osc*: array[2, Oscillator]
    lowpass*: ImprovedMoog
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
    
    result.lowpass = newImprovedMoog(48000.0)
    result.lowpass.setCutoff(12000.0)

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
    result = synth.lowpass.render(result)
    
    inc synth.runtime
    if synth.adsr[0].finished:
        synth.finished = true

proc release*(synth: var AudioSynth) =
    synth.adsr[0].release()
    # synth.adsr[1].release()
