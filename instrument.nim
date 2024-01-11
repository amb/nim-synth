import std/[math]
import audiosynth

type Instrument* = ref object
    voices: seq[AudioSynth]
    activeNotes: array[128, AudioSynth]
    volume: float32

proc newInstrument*(): Instrument =
    result = Instrument()
    result.volume = 1.0

proc stopInactiveVoices(instrument: var Instrument) =
    # TODO: just sort in place as there are only two types, it's O(n) then
    var newVoices: seq[AudioSynth]
    for voice in instrument.voices:
        if not voice.finished:
            newVoices.add(voice)
    instrument.voices = newVoices

proc addVoice(instrument: var Instrument, note: int, synth: AudioSynth) =
    assert note >= 0 and note < 128
    if instrument.activeNotes[note] != nil:
        instrument.activeNotes[note].release()
    instrument.voices.add(synth)
    instrument.activeNotes[note] = synth

proc endVoice(instrument: var Instrument, note: int) =
    assert note >= 0 and note < 128
    instrument.activeNotes[note].release()

proc noteOn*(instrument: var Instrument, note: int, velocity: float32) =
    assert note >= 0 and note < 128
    # echo "Note on: ", note, " ", velocity
    instrument.addVoice(note, newAudioSynth(440.0 * pow(2, (note-69).float32/12), velocity))

proc noteOff*(instrument: var Instrument, note: int) =
    assert note >= 0 and note < 128
    # echo "Note off: ", note
    instrument.endVoice(note)

proc controlMessage*(instrument: var Instrument, control: int, value: int) =
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
    elif control == 0x05:
        # TODO: finish
        # portamento time
        discard
    elif control == 0x06:
        # data entry (MSB)
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
    elif control == 0x41:
        # portamento
        discard
    else:
        echo "Unhandled control event: ", control, " ", value

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
