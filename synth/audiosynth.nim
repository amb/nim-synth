import std/[sequtils, math, random, tables, strformat]
import ../midi/[encoders, formulas]
import components/[adsr, osc, resonant]
import network

type AudioSynth* = object
    # IMPORTANT: try keep this non-variable size
    adsr: array[2, ADSR]
    osc: array[2, Oscillator]
    lowpass: Resonant

    sampleRate: float32
    sampleTime: float32
    released: bool
    finished: bool

    params*: OrderedTable[string, EncoderInput]

const initParams = {
    # TODO: keep as many as possible normalized between 0 and 1
    "osc1freq": newEncoderInput(0.0, 1.0, -48.0, 48.0),
    "osc1famp": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "osc1feed": newEncoderInput(0.2, 0.01, 0.0, 1.0),

    "osc2freq": newEncoderInput(0.0, 1.0, -48.0, 48.0),
    "osc2amp": newEncoderInput(1.0, 0.02, 0.0, 1.0),
    "osc2feed": newEncoderInput(0.0, 0.01, 0.0, 1.0),

    "adsr1attack": newEncoderInput(0.002, 0.01, 0.0, 1.0),
    "adsr1decay": newEncoderInput(0.1, 0.01, 0.0, 1.0),
    "adsr1sustain": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "adsr1release": newEncoderInput(0.2, 0.01, 0.0, 1.0),

    "adsr2attack": newEncoderInput(0.01, 0.01, 0.0, 1.0),
    "adsr2decay": newEncoderInput(0.01, 0.01, 0.0, 1.0),
    "adsr2sustain": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "adsr2release": newEncoderInput(0.01, 0.01, 0.0, 1.0),

    "lpcutoff": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "lpresonance": newEncoderInput(0.2, 0.01, 0.0, 0.99)
}.toOrderedTable

proc getParamList*(synth: var AudioSynth): OrderedTable[string, EncoderInput] =
    for p in synth.params.pairs():
        result[p[0]] = p[1]

proc isFinished*(synth: AudioSynth): bool =
    result = synth.finished

proc finish*(synth: var AudioSynth) =
    synth.released = true
    synth.finished = true

proc isReleased*(synth: AudioSynth): bool =
    result = synth.released

proc release*(synth: var AudioSynth) =
    synth.released = true
    synth.adsr[0].release()

proc reset*(synth: var AudioSynth) =
    synth.finished = false
    synth.released = false
    synth.adsr[0].reset()
    synth.adsr[1].reset()

proc applyParams(synth: var AudioSynth) =
    synth.osc[0].amplitude = synth.params["osc1famp"].value
    synth.osc[0].feedback = synth.params["osc1feed"].value
    synth.osc[1].amplitude = synth.params["osc2amp"].value
    synth.osc[1].feedback = synth.params["osc2feed"].value
    synth.adsr[0].attack = synth.params["adsr1attack"].curve(-1.0)
    synth.adsr[0].decay = synth.params["adsr1decay"].curve(-1.0)
    synth.adsr[0].sustain = synth.params["adsr1sustain"].value
    synth.adsr[0].release = synth.params["adsr1release"].value
    synth.adsr[1].attack = synth.params["adsr2attack"].curve(-1.0)
    synth.adsr[1].decay = synth.params["adsr2decay"].curve(-1.0)
    synth.adsr[1].sustain = synth.params["adsr2sustain"].value
    synth.adsr[1].release = synth.params["adsr2release"].value
    synth.lowpass.setResonance(synth.params["lpresonance"].value)
    synth.lowpass.setCutoff(synth.params["lpcutoff"].value)

proc render*(synth: var AudioSynth): float32 =
    if synth.finished:
        return 0.0

    let st = synth.sampleTime

    # Oscillators
    let osc2 = synth.osc[1].render(sin_wt, st, 0.0)
    let osc1 = synth.osc[0].render(sin_wt, st, osc2)

    # VCF
    let adsr2 = synth.adsr[1].render(st)
    var cutoffVal = synth.params["lpcutoff"].value
    cutoffVal = cutoffVal * cutoffVal
    cutoffVal *= adsr2
    synth.lowpass.setCutoff(cutoffVal)
    result = synth.lowpass.render(osc1)

    # VCA
    result *= synth.adsr[0].render(st)
    if synth.adsr[0].finished:
        synth.finished = true

proc spawnFrom*(synth: AudioSynth): AudioSynth =
    result = synth
    result.reset()

proc setNote*(synth: var AudioSynth, note, amplitude: float32) =
    synth.osc[0].frequency = noteToFreq(note + synth.params["osc1freq"].value)
    synth.osc[0].amplitude = amplitude
    synth.osc[1].frequency = noteToFreq(note + synth.params["osc2freq"].value)
    synth.applyParams()

proc newAudioSynth*(frequency, amplitude, sampleRate: float32): AudioSynth =
    result = AudioSynth()
    result.sampleRate = sampleRate
    result.sampleTime = 1.0 / sampleRate

    for item in initParams.pairs():
        result.params[item[0]] = item[1]

    result.adsr[0] = ADSR()
    result.adsr[1] = ADSR()
    result.osc[0] = Oscillator()
    result.osc[1] = Oscillator()
    result.lowpass = Resonant()
    result.setNote(frequency, amplitude)

proc nudgeParam*(synth: var AudioSynth, name: string, value: int) =
    synth.params[name].updateRelative(value)
    echo fmt"{name} = {synth.params[name].value:.3f}"
    synth.applyParams()

proc setParam*(synth: var AudioSynth, name: string, value: float32) =
    # synth.params[name].updateMiddle(value - 64)
    synth.params[name].updateAbsolute(int(value * 127.0))
    echo fmt"{name} = {synth.params[name].value:.3f}"
    synth.applyParams()
