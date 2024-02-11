import std/[sequtils, math, random, tables, strformat]
import components/[adsr, osc, moog24]
import audiocomponent
import midi/encoders

type SynthParamKind* = enum
    Osc1Freq, Osc1Amp, Osc1Feed,
    Osc2Freq, Osc2Amp, Osc2Feed,
    Adsr1Attack, Adsr1Decay, Adsr1Sustain, Adsr1Release,
    Adsr2Attack, Adsr2Decay, Adsr2Sustain, Adsr2Release,
    LowpassCutoff, LowpassResonance

type AudioSynth* = object
    # IMPORTANT: try keep this non-variable size
    adsr: array[2, ADSR]
    osc: array[2, Oscillator]
    lowpass: MoogVCF
    component*: AudioComponent
    params*: array[SynthParamKind, EncoderInput]

const initParams = {
    # TODO: keep as many as possible normalized between 0 and 1
    Osc1Freq: newEncoderInput(0.0, 1.0, -48.0, 48.0),
    Osc1Amp: newEncoderInput(1.0, 0.01, 0.0, 1.0),
    Osc1Feed: newEncoderInput(0.2, 0.01, 0.0, 1.0),

    Osc2Freq: newEncoderInput(0.0, 1.0, -48.0, 48.0),
    Osc2Amp: newEncoderInput(1.0, 0.02, 0.0, 1.0),
    Osc2Feed: newEncoderInput(0.0, 0.01, 0.0, 1.0),

    Adsr1Attack: newEncoderInput(0.002, 0.01, 0.0, 1.0),
    Adsr1Decay: newEncoderInput(0.1, 0.01, 0.0, 1.0),
    Adsr1Sustain: newEncoderInput(1.0, 0.01, 0.0, 1.0),
    Adsr1Release: newEncoderInput(0.2, 0.01, 0.0, 1.0),

    Adsr2Attack: newEncoderInput(0.01, 0.01, 0.0, 1.0),
    Adsr2Decay: newEncoderInput(0.01, 0.01, 0.0, 1.0),
    Adsr2Sustain: newEncoderInput(1.0, 0.01, 0.0, 1.0),
    Adsr2Release: newEncoderInput(0.01, 0.01, 0.0, 1.0),

    LowpassCutoff: newEncoderInput(12.0, 0.2, 0.0, 1.0),
    LowpassResonance: newEncoderInput(0.2, 0.01, 0.0, 1.0)
}.toTable

proc getParamList*(synth: var AudioSynth): array[SynthParamKind, EncoderInput] =
    for p in synth.params.pairs():
        result[p[0]] = p[1]

proc applyParams(synth: var AudioSynth) =
    synth.osc[0].amplitude = synth.params[Osc1Amp].value
    synth.osc[0].feedback = synth.params[Osc1Feed].value
    synth.osc[1].amplitude = synth.params[Osc2Amp].value
    synth.osc[1].feedback = synth.params[Osc2Feed].value
    synth.adsr[0].attack = synth.params[Adsr1Attack].curve(-1.0)
    synth.adsr[0].decay = synth.params[Adsr1Decay].curve(-1.0)
    synth.adsr[0].sustain = synth.params[Adsr1Sustain].value
    synth.adsr[0].release = synth.params[Adsr1Release].value
    synth.adsr[1].attack = synth.params[Adsr2Attack].curve(-1.0)
    synth.adsr[1].decay = synth.params[Adsr2Decay].curve(-1.0)
    synth.adsr[1].sustain = synth.params[Adsr2Sustain].value
    synth.adsr[1].release = synth.params[Adsr2Release].value
    synth.lowpass.initMoogVCF(
        synth.params[LowpassCutoff].value * 16.0 * synth.osc[0].frequency, 
        synth.component.sampleRate, 
        synth.params[LowpassResonance].value)

proc initSynth(sampleRate: float32): AudioSynth =
    result = AudioSynth()
    result.component = newAudioComponent(sampleRate)

    for item in initParams.pairs():
        result.params[item[0]] = item[1]

    result.adsr[0] = ADSR()
    result.adsr[1] = ADSR()
    result.osc[0] = Oscillator()
    result.osc[1] = Oscillator()
    result.lowpass = MoogVCF()

proc render*(synth: var AudioSynth): float32 =
    if synth.component.isFinished():
        return 0.0

    let st = synth.component.sampleTime()
    
    let osc2 = synth.osc[1].render(sin_wt, st, 0.0)
    let osc1 = synth.osc[0].render(sin_wt, st, osc2)

    result = synth.lowpass.processMoogVCF(osc1)

    result *= synth.adsr[0].render(st)

    if synth.adsr[0].finished:
        synth.component.finish()

proc spawnFrom*(synth: AudioSynth): AudioSynth =
    result = synth
    result.component.reset()

proc noteToFreq(note: float32): float32 {.inline.} = pow(2.0, (note - 69.0) / 12.0) * 440.0

proc setNote*(synth: var AudioSynth, note, amplitude: float32) =
    synth.osc[0].frequency = noteToFreq(note + synth.params[Osc1Freq].value)
    synth.osc[0].amplitude = amplitude
    synth.osc[1].frequency = noteToFreq(note + synth.params[Osc2Freq].value)
    synth.applyParams()

proc newAudioSynth*(frequency, amplitude, sampleRate: float32): AudioSynth =
    result = initSynth(sampleRate)
    result.setNote(frequency, amplitude)

proc release*(synth: var AudioSynth) =
    synth.adsr[0].release()

proc nudgeParam*(synth: var AudioSynth, name: SynthParamKind, value: int) =
    synth.params[name].updateRelative(value)
    echo fmt"{name} = {synth.params[name].value:.3f}"
    synth.applyParams()

proc setParam*(synth: var AudioSynth, name: SynthParamKind, value: float32) =
    # synth.params[name].updateMiddle(value - 64)
    synth.params[name].updateAbsolute(int(value * 127.0))
    echo fmt"{name} = {synth.params[name].value:.3f}"
    synth.applyParams()
