import std/[sequtils, math, random, tables]
import components/[adsr, osc, impfilter]
import audiocomponent
import midi/encoders

type AudioSynth* = object
    # IMPORTANT: keep this non-variable size
    adsr: array[2, ADSR]
    osc: array[2, Oscillator]
    lowpass: ImprovedMoog
    component*: AudioComponent
    params*: Table[string, EncoderInput]

const defaultParams = {
    "osc1.freq": newEncoderInput(0.0, 1.0, -48.0, 48.0),
    "osc1.amp": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "osc1.feedback": newEncoderInput(0.2, 0.01, 0.0, 1.0),
    
    "osc2.freq": newEncoderInput(0.0, 1.0, -48.0, 48.0),
    "osc2.amp": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "osc2.feedback": newEncoderInput(0.0, 0.01, 0.0, 1.0),
    
    "adsr1.attack": newEncoderInput(0.002, 0.01, 0.0, 1.0),
    "adsr1.decay": newEncoderInput(0.1, 0.01, 0.0, 1.0),
    "adsr1.sustain": newEncoderInput(0.5, 0.01, 0.0, 1.0),
    "adsr1.release": newEncoderInput(0.2, 0.01, 0.0, 1.0),
    
    "adsr2.attack": newEncoderInput(0.01, 0.01, 0.0, 1.0),
    "adsr2.decay": newEncoderInput(0.01, 0.01, 0.0, 1.0),
    "adsr2.sustain": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "adsr2.release": newEncoderInput(0.01, 0.01, 0.0, 1.0),
    
    "lowpass.cutoff": newEncoderInput(0.5, 0.02, 0.0, 4.0),
    "lowpass.resonance": newEncoderInput(0.2, 0.02, 0.0, 3.0)
}.toTable

proc paramNames*(synth: var AudioSynth): seq[string] = defaultParams.keys.toSeq()

proc expCurve(x: float32): float32 = x * x
proc logCurve(x: float32): float32 = 1.0 - (1.0 - x) * (1.0 - x)

proc applyParams*(synth: var AudioSynth) =
    synth.osc[0].amplitude = synth.params["osc1.amp"].value
    synth.osc[0].feedback = synth.params["osc1.feedback"].value
    synth.osc[1].amplitude = synth.params["osc2.amp"].value
    synth.osc[1].feedback = synth.params["osc2.feedback"].value
    synth.adsr[0].attack = synth.params["adsr1.attack"].value
    synth.adsr[0].decay = synth.params["adsr1.decay"].value
    synth.adsr[0].sustain = synth.params["adsr1.sustain"].value
    synth.adsr[0].release = synth.params["adsr1.release"].value
    synth.adsr[1].attack = synth.params["adsr2.attack"].value
    synth.adsr[1].decay = synth.params["adsr2.decay"].value
    synth.adsr[1].sustain = synth.params["adsr2.sustain"].value
    synth.adsr[1].release = synth.params["adsr2.release"].value
    synth.lowpass.setCutoff(synth.params["lowpass.cutoff"].value * synth.params["osc1.freq"].value)
    synth.lowpass.setResonance(synth.params["lowpass.resonance"].value)

proc setNote*(synth: var AudioSynth, frequency, amplitude: float32) =
    synth.osc[0].frequency = pow(2.0, (frequency - 69.0 + synth.params["osc1.freq"].value) / 12.0) * 440.0
    synth.osc[0].amplitude = amplitude
    synth.osc[1].frequency = pow(2.0, (frequency - 69.0 + synth.params["osc2.freq"].value) / 12.0) * 440.0
    synth.applyParams()

proc newAudioSynth*(frequency, amplitude, sampleRate: float32): AudioSynth =
    # Synth defaults defined here
    result = AudioSynth()
    result.component = newAudioComponent(sampleRate)

    for item in defaultParams.pairs():
        result.params[item[0]] = item[1]

    result.adsr[0] = ADSR()
    result.osc[0] = Oscillator()
    result.adsr[1] = ADSR()
    result.osc[1] = Oscillator()
    result.lowpass = newImprovedMoog(sampleRate)

    result.setNote(frequency, amplitude)

proc spawnFrom*(synth: AudioSynth): AudioSynth =
    result = synth
    result.component.reset()

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

# proc setParam*(synth: var AudioSynth, name: string, value: float32) =
#     synth.params[name] = value
#     synth.applyParams()

proc nudgeParam*(synth: var AudioSynth, name: string, value: int) =
    synth.params[name].updateRelative(value)
    synth.applyParams()