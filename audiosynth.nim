import std/[math]

const SampleRate = 48000.0

type ControlMessage* = enum Release, PitchBend

type ADSR* = ref object
    attack: uint64
    decay: uint64
    sustain: float32
    release: uint64
    released: bool
    renderedSamples: uint64
    active*: bool

proc render*(adsr: var ADSR): float32 =
    if not adsr.active:
        return 0.0

    let rma = adsr.renderedSamples.float32 - adsr.attack.float32
    
    # Attack envelope
    if adsr.renderedSamples < adsr.attack:
        result = adsr.renderedSamples.float32 / adsr.attack.float32
        inc adsr.renderedSamples
    # Decay envelope
    elif adsr.renderedSamples < adsr.attack + adsr.decay:
        result = 1.0 - rma / adsr.decay.float32 * (1.0 - adsr.sustain)
        inc adsr.renderedSamples
    # Wait until release
    elif not adsr.released:
        result = adsr.sustain
    # Release envelope
    elif adsr.renderedSamples < adsr.attack + adsr.decay + adsr.release:
        result = adsr.sustain - (rma - adsr.decay.float32) / adsr.release.float32 * adsr.sustain
        inc adsr.renderedSamples
    # End of envelope
    else:
        adsr.active = false

type SinOsc* = ref object
    frequency: float32
    amplitude: float32
    phase: float32

proc render*(osc: var SinOsc): float32 =
    result = sin(osc.frequency * osc.phase * math.PI * 2.0)
    result *= osc.amplitude
    osc.phase += 1.0 / SampleRate
    osc.phase -= max(0, osc.phase.int - 1).float32

type AudioSynth* = ref object
    renderedSamples: uint64
    adsr: ADSR
    osc: SinOsc
    active*: bool

proc newAudioSynth*(frequency: float32): AudioSynth =
    result = AudioSynth()
    result.adsr = ADSR(attack: 100, decay: 1000, sustain: 0.5, release: 20000, active: true)
    result.osc = SinOsc(frequency: frequency, amplitude: 1.0, phase: 0.0)
    result.renderedSamples = 0
    result.active = true

proc render*(synth: var AudioSynth): float32 =
    if not synth.active:
        return 0.0
    result = synth.osc.render()
    result *= synth.adsr.render()
    inc synth.renderedSamples
    if not synth.adsr.active:
        synth.active = false

proc message*(synth: var AudioSynth, msg: ControlMessage) =
    case msg
    of ControlMessage.Release:
        synth.adsr.released = true
    of ControlMessage.PitchBend:
        discard
