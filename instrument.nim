import std/[math]
import audiosynth

type Instrument* = ref object
    voices: seq[AudioSynth]
    activeNotes: array[128, AudioSynth]
    adsr: ADSR
    volume: float32

proc newInstrument*(): Instrument =
    result = Instrument()
    result.adsr = ADSR(attack: 0.002, decay: 0.1, sustain: 0.5, release: 0.1)
    result.volume = 1.0

proc stopInactiveVoices(instrument: var Instrument) =
    # TODO: just sort in place as there are only two types, it's O(n) then
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

proc newVoice(instrument: Instrument, frequency, amplitude: float32): AudioSynth =
    result = AudioSynth()
    result.adsr = ADSR(
        attack: instrument.adsr.attack,
        decay: instrument.adsr.decay,
        sustain: instrument.adsr.sustain,
        release: instrument.adsr.release)
    result.osc = Oscillator(frequency: frequency, amplitude: amplitude, phase: 0.0)

proc noteOn*(instrument: var Instrument, note: int, velocity: float32) =
    assert note >= 0 and note < 128
    echo "Note on: ", note, " ", velocity
    instrument.addVoice(note, instrument.newVoice(440.0 * pow(2, (note-69).float32/12), velocity))

proc noteOff*(instrument: var Instrument, note: int) =
    assert note >= 0 and note < 128
    echo "Note off: ", note
    instrument.endVoice(note)

# TODO: the whole note playing logic might not be correct: refactoring needed
proc notePlaying*(instrument: Instrument, note: int): bool =
    assert note >= 0 and note < 128
    if instrument.activeNotes[note] != nil:
        if not instrument.activeNotes[note].released:
            result = true
    result = false

proc controlMessage*(instrument: var Instrument, control: int, value: int) =
    # TODO: this is hardcoded, make it configurable
    let mval = max(1, value)
    # if control == 1:
    #     instrument.adsr.attack = mval.float32 / 127.0 * 0.05
    # elif control == 2:
    #     instrument.adsr.decay = mval.float32 / 127.0 * 0.2
    # elif control == 4:
    #     instrument.adsr.sustain = mval.float32 / 127.0
    # elif control == 12:
    #     instrument.adsr.release = mval.float32 / 127.0
    if control == 0x01:
        # modulation
        discard
    elif control == 0x07:
        # volume
        instrument.volume = mval.float32 / 127.0
    elif control == 0x0A:
        # pan
        discard
    elif control == 0x0B:
        # expression
        discard
    else:
        echo "Unhandled control event: ", control, " ", value

    # TODO: portamento 0x41 and 0x05

proc render*(instrument: var Instrument): float32 =
    var cleanup = false
    for i in 0..<instrument.voices.len:
        let vc = instrument.voices[i]
        if vc == nil:
            continue
        if not vc.finished:
            result += instrument.voices[i].render() * instrument.volume
        else:
            cleanup = true
    if cleanup:
        instrument.stopInactiveVoices()
