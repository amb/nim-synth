import raylib, std/[sequtils, math, sets]

type AudioSynth* = ref object
    frequency: float32
    renderedSamples: int
    active*: bool

proc newAudioSynth*(frequency: float32): AudioSynth =
    result = AudioSynth()
    result.frequency = frequency
    result.renderedSamples = 0
    result.active = true

proc render*(synth: var AudioSynth): float32 =
    if not synth.active:
        return 0.0
    result = sin(synth.frequency * synth.renderedSamples.float32 / 48000.0)
    inc synth.renderedSamples

    let ampCurve = 1.0 - synth.renderedSamples.float32 / 20_000.0
    result *= ampCurve

    if synth.renderedSamples >= 20_000:
        synth.active = false
