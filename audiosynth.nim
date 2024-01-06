import raylib, std/[sequtils, math, sets]

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

type AudioSynth* = ref object
    frequency: float32
    renderedSamples: uint64
    adsr: ADSR
    active*: bool

proc newAudioSynth*(frequency: float32): AudioSynth =
    result = AudioSynth()
    result.adsr = ADSR(attack: 100, decay: 1000, sustain: 0.5, release: 20000, active: true)
    result.frequency = frequency
    result.renderedSamples = 0
    result.active = true

proc render*(synth: var AudioSynth): float32 =
    if not synth.active:
        return 0.0
    result = sin(synth.frequency * synth.renderedSamples.float32 / 48000.0)
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
