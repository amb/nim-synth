import std/[sequtils, math, random, tables, strformat]
import components/[adsr, osc, moog24]
import audiocomponent
import midi/encoders

type AudioSynth* = object
    # IMPORTANT: try keep this non-variable size
    adsr: array[2, ADSR]
    osc: array[2, Oscillator]
    lowpass: MoogVCF
    component*: AudioComponent
    params*: Table[string, EncoderInput]

const defaultParams = {
    "osc1.freq": newEncoderInput(0.0, 1.0, -48.0, 48.0),
    "osc1.amp": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "osc1.feedback": newEncoderInput(0.2, 0.01, 0.0, 1.0),
    
    "osc2.freq": newEncoderInput(0.0, 1.0, -48.0, 48.0),
    "osc2.amp": newEncoderInput(1.0, 0.02, 0.0, 4.0),
    "osc2.feedback": newEncoderInput(0.0, 0.01, 0.0, 1.0),
    
    "adsr1.attack": newEncoderInput(0.002, 0.01, 0.0, 1.0),
    "adsr1.decay": newEncoderInput(0.1, 0.01, 0.0, 1.0),
    "adsr1.sustain": newEncoderInput(0.5, 0.01, 0.0, 1.0),
    "adsr1.release": newEncoderInput(0.2, 0.01, 0.0, 1.0),
    
    "adsr2.attack": newEncoderInput(0.01, 0.01, 0.0, 1.0),
    "adsr2.decay": newEncoderInput(0.01, 0.01, 0.0, 1.0),
    "adsr2.sustain": newEncoderInput(1.0, 0.01, 0.0, 1.0),
    "adsr2.release": newEncoderInput(0.01, 0.01, 0.0, 1.0),
    
    "lowpass.cutoff": newEncoderInput(4.0, 0.2, 0.0, 16.0),
    "lowpass.resonance": newEncoderInput(0.2, 0.01, 0.0, 0.9)
}.toTable

proc paramNames*(synth: var AudioSynth): seq[string] = defaultParams.keys.toSeq()

proc expCurve(x: float32): float32 {.inline.} = x * x
proc logCurve(x: float32): float32 {.inline.} = 1.0 - (1.0 - x) * (1.0 - x)
proc noteToFreq(note: float32): float32 {.inline.} = pow(2.0, (note - 69.0) / 12.0) * 440.0

proc applyParams*(synth: var AudioSynth) =
    synth.osc[0].amplitude = synth.params["osc1.amp"].value
    synth.osc[0].feedback = synth.params["osc1.feedback"].value
    synth.osc[1].amplitude = synth.params["osc2.amp"].value
    synth.osc[1].feedback = synth.params["osc2.feedback"].value
    synth.adsr[0].attack = synth.params["adsr1.attack"].expCurve(1.0)
    synth.adsr[0].decay = synth.params["adsr1.decay"].expCurve(1.0)
    synth.adsr[0].sustain = synth.params["adsr1.sustain"].value
    synth.adsr[0].release = synth.params["adsr1.release"].value
    synth.adsr[1].attack = synth.params["adsr2.attack"].expCurve(1.0)
    synth.adsr[1].decay = synth.params["adsr2.decay"].expCurve(1.0)
    synth.adsr[1].sustain = synth.params["adsr2.sustain"].value
    synth.adsr[1].release = synth.params["adsr2.release"].value
    synth.lowpass.initMoogVCF(
        synth.params["lowpass.cutoff"].expCurve(1.0) * synth.osc[0].frequency, 
        synth.component.sampleRate, 
        synth.params["lowpass.resonance"].value)

proc setNote*(synth: var AudioSynth, frequency, amplitude: float32) =
    synth.osc[0].frequency = noteToFreq(frequency + synth.params["osc1.freq"].value)
    synth.osc[0].amplitude = amplitude
    synth.osc[1].frequency = noteToFreq(frequency + synth.params["osc2.freq"].value)
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
    result.lowpass = MoogVCF()

    result.setNote(frequency, amplitude)

proc spawnFrom*(synth: AudioSynth): AudioSynth =
    result = synth
    result.component.reset()

proc render*(synth: var AudioSynth): float32 =
    if synth.component.isFinished():
        return 0.0

    let st = synth.component.sampleTime()
    
    let osc2 = synth.osc[1].render(sin_wt, st, 0.0)
    let osc1 = synth.osc[0].render(sin_wt, st, osc2)

    let cutoff = synth.params["lowpass.cutoff"].value * synth.osc[0].frequency
    synth.lowpass.setCutOff(cutoff * synth.adsr[1].render(st))
    result = synth.lowpass.processMoogVCF(osc1)

    result *= synth.adsr[0].render(st)

    if synth.adsr[0].finished:
        synth.component.finish()

proc release*(synth: var AudioSynth) =
    synth.adsr[0].release()

# proc setParam*(synth: var AudioSynth, name: string, value: float32) =
#     synth.params[name] = value
#     synth.applyParams()

proc nudgeParam*(synth: var AudioSynth, name: string, value: int) =
    synth.params[name].updateRelative(value)
    echo fmt"{name} = {synth.params[name].value:.3f}"
    synth.applyParams()
