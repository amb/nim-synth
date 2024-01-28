import std/[sequtils, math, random, tables]
import components/[adsr, osc, impfilter]
import audiocomponent

type AudioSynth* = object
    # IMPORTANT: keep this non-variable size
    adsr: array[2, ADSR]
    osc: array[2, Oscillator]
    lowpass: ImprovedMoog
    oscRatio: float32
    component*: AudioComponent
    params*: Table[string, float32]

let defaultParams = {
    "oscRatio": 0.5,
    "osc1.freq": 440.0,
    "osc1.amp": 1.0,
    "osc1.feedback": 0.2,
    "osc2.freq": 440.0 * 0.5,
    "osc2.amp": 1.0,
    "osc2.feedback": 0.0,
    "adsr1.attack": 0.002,
    "adsr1.decay": 0.1,
    "adsr1.sustain": 0.5,
    "adsr1.release": 0.2,
    "adsr2.attack": 0.01,
    "adsr2.decay": 0.01,
    "adsr2.sustain": 1.0,
    "adsr2.release": 0.01,
    "lowpass.cutoff": 0.5,
    "lowpass.resonance": 0.2
}.toTable

proc paramNames*(synth: var AudioSynth): seq[string] = defaultParams.keys.toSeq()

proc expCurve(x: float32): float32 = x * x
proc logCurve(x: float32): float32 = 1.0 - (1.0 - x) * (1.0 - x)

proc applyParams*(synth: var AudioSynth) =
    synth.oscRatio = synth.params["oscRatio"]
    synth.osc[0].frequency = synth.params["osc1.freq"]
    synth.osc[0].amplitude = synth.params["osc1.amp"]
    synth.osc[0].feedback = synth.params["osc1.feedback"]
    synth.osc[1].frequency = synth.params["osc2.freq"]
    synth.osc[1].amplitude = synth.params["osc2.amp"]
    synth.osc[1].feedback = synth.params["osc2.feedback"]
    synth.adsr[0].attack = synth.params["adsr1.attack"]
    synth.adsr[0].decay = synth.params["adsr1.decay"]
    synth.adsr[0].sustain = synth.params["adsr1.sustain"]
    synth.adsr[0].release = synth.params["adsr1.release"]
    synth.adsr[1].attack = synth.params["adsr2.attack"]
    synth.adsr[1].decay = synth.params["adsr2.decay"]
    synth.adsr[1].sustain = synth.params["adsr2.sustain"]
    synth.adsr[1].release = synth.params["adsr2.release"]
    synth.lowpass.setCutoff((synth.params["lowpass.cutoff"] * 4.0) * synth.params["osc1.freq"])
    synth.lowpass.setResonance(synth.params["lowpass.resonance"] * 3.0)

proc newAudioSynth*(frequency, amplitude: float32): AudioSynth =
    # Synth defaults defined here
    result = AudioSynth()

    result.component = newAudioComponent(48000.0)

    for item in defaultParams.pairs():
        result.params[item[0]] = item[1].float32
    # result.params = defaultParams

    result.params["osc1.freq"] = frequency
    result.params["osc1.amp"] = amplitude
    result.params["osc2.freq"] = frequency * result.oscRatio
    
    result.adsr[0] = ADSR()
    result.osc[0] = Oscillator()
    result.adsr[1] = ADSR()
    result.osc[1] = Oscillator()
    result.lowpass = newImprovedMoog(result.component.sampleRate())

    result.applyParams()

proc spawnFrom*(synth: AudioSynth): AudioSynth =
    result = synth
    result.component.reset()

proc setNote*(synth: var AudioSynth, frequency, amplitude: float32) =
    synth.params["osc1.freq"] = frequency
    synth.params["osc1.amp"] = amplitude
    synth.params["osc2.freq"] = frequency * synth.params["oscRatio"]
    synth.applyParams()

proc render*(synth: var AudioSynth): float32 =
    if synth.component.isFinished():
        return 0.0

    let st = synth.component.sampleTime()
    var osc1 = synth.osc[1].render(osc_sin, st, 0.0)
    osc1 *= synth.adsr[1].render(st)
    result = synth.osc[0].render(osc_sin, st, osc1)
    result *= synth.adsr[0].render(st)
    # result = synth.lowpass.render(result)
    # result = osc1 * synth.adsr[0].render(st)

    synth.component.tick()
    if synth.adsr[0].finished:
        synth.component.finish()

proc release*(synth: var AudioSynth) =
    synth.adsr[0].release()
    # synth.adsr[1].release()

proc getParams*(synth: var AudioSynth): Table[string, float32] =
    result = synth.params

proc setParam*(synth: var AudioSynth, name: string, value: float32) =
    synth.params[name] = value
    synth.applyParams()
