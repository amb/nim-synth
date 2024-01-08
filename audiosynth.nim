import std/[math]

const SampleRate = 48000.0
const OneDivSampleRate = 1.0 / SampleRate

type ADSR* = ref object
    attack: float32
    decay: float32
    sustain: float32
    release: float32
    progress: float32
    released: bool
    finished*: bool

proc render*(adsr: var ADSR): float32 =
    if adsr.finished:
        return 0.0

    # Attack envelope
    if adsr.progress < adsr.attack:
        result = adsr.progress / adsr.attack
        adsr.progress += OneDivSampleRate
    # Decay envelope
    elif adsr.progress < adsr.attack + adsr.decay:
        result = 1.0 - (adsr.progress - adsr.attack) / adsr.decay * (1.0 - adsr.sustain)
        adsr.progress += OneDivSampleRate
    # Sustain
    elif adsr.progress < adsr.attack + adsr.decay + adsr.release and not adsr.released:
        result = adsr.sustain
    # Release envelope
    elif adsr.released:
        result = adsr.sustain - (adsr.progress - adsr.attack - adsr.decay) / adsr.release * adsr.sustain
        adsr.progress += OneDivSampleRate
        # Finished
        if adsr.progress >= adsr.attack + adsr.decay + adsr.release:
            adsr.finished = true

type Oscillator* = ref object
    frequency: float32
    amplitude: float32
    phase: float32

proc osc_sin*(phase: float32): float32 = sin(phase * math.PI * 2.0)
proc osc_saw*(phase: float32): float32 = phase * 2.0 - 1.0
proc osc_sqr*(phase: float32): float32 = (if phase < 0.5: 1.0 else: -1.0)

proc osc_harmonic_sqr*(phase: float32, numHarmonics: int): float32 =
    for i in 1..<numHarmonics:
        let n = i.float32 * 2.0 - 1.0
        result += osc_sin(phase * n) / n
    result *= 4.0 / math.PI

proc osc_hsqr9*(phase: float32): float32 = osc_harmonic_sqr(phase, 19)

proc osc_harmonic_saw*(phase: float32, numHarmonics: int): float32 =
    for i in 1..<numHarmonics:
        let n = i.float32
        result += pow(-1, n) * osc_sin(phase * n) / n
    result = 0.5 - result / math.PI

proc osc_hsaw9*(phase: float32): float32 = osc_harmonic_saw(phase, 19)

proc render*(osc: var Oscillator, osc_func: proc (phase: float32): float32): float32 =
    result = osc_func(osc.phase)
    result *= osc.amplitude
    osc.phase += osc.frequency * OneDivSampleRate
    osc.phase -= max(0, osc.phase.int).float32

type AudioSynth* = ref object
    adsr: ADSR
    osc: Oscillator
    finished*: bool

proc newAudioSynth(frequency, amplitude: float32): AudioSynth =
    result = AudioSynth()
    result.adsr = ADSR(attack: 0.002, decay: 0.02, sustain: 0.5, release: 0.5)
    result.osc = Oscillator(frequency: frequency, amplitude: amplitude, phase: 0.0)

proc render*(synth: var AudioSynth): float32 =
    if synth.finished:
        return 0.0
    result = synth.osc.render(osc_hsaw9)
    result *= synth.adsr.render()
    if synth.adsr.finished:
        synth.finished = true

proc release(synth: var AudioSynth) =
    synth.adsr.released = true

type Instrument* = ref object
    voices: seq[AudioSynth]
    activeNotes: array[128, AudioSynth]

proc newInstrument*(): Instrument =
    result = Instrument()
    result.voices = newSeq[AudioSynth](16)

proc stopInactiveVoices(instrument: var Instrument) =
    var newVoices: seq[AudioSynth]
    for voice in instrument.voices:
        if not voice.finished:
            newVoices.add(voice)
    instrument.voices = newVoices

proc addVoice(instrument: var Instrument, channel: int, synth: AudioSynth) =
    assert channel >= 0 and channel < 128
    instrument.voices.add(synth)
    instrument.activeNotes[channel] = synth

proc endVoice(instrument: var Instrument, channel: int) =
    assert channel >= 0 and channel < 128
    instrument.activeNotes[channel].release()

proc noteOn*(instrument: var Instrument, note: int, velocity: float32) =
    assert note >= 0 and note < 128
    instrument.addVoice(note, newAudioSynth(440.0 * pow(2, (note-69).float32/12), velocity))

proc noteOff*(instrument: var Instrument, note: int) =
    assert note >= 0 and note < 128
    instrument.endVoice(note)

proc render*(instrument: var Instrument): float32 =
    var cleanup = false
    for i in 0..<instrument.voices.len:
        if not instrument.voices[i].finished:
            result += instrument.voices[i].render()
        else:
            cleanup = true
    if cleanup:
        instrument.stopInactiveVoices()
