import std/[math]
import audiosynth

type Instrument* = ref object
    voices: seq[tuple[note: int, synth: AudioSynth]]
    volume: float32

proc newInstrument*(): Instrument =
    result = Instrument()
    result.volume = 1.0

# proc stopInactiveNotes(instrument: var Instrument) =
#     let voices = instrument.voices
#     var a = 0
#     var b = voices.len - 1

#     if a == b:
#         if voices[a].synth.finished:
#             instrument.voices.setLen(0)
#         return

#     while a < b:
#         if not voices[a].synth.finished and voices[b].synth.finished:
#             swap(instrument.voices[a], instrument.voices[b])
#         if voices[a].synth.finished:
#             inc a
#         if not voices[b].synth.finished:
#             dec b

#     instrument.voices.setLen(a)

proc stopInactiveNotes(instrument: var Instrument) =
    var newNotes = newSeq[tuple[note: int, synth: AudioSynth]]()
    for i in 0..<instrument.voices.len:
        if not instrument.voices[i].synth.finished:
            newNotes.add(instrument.voices[i])
    instrument.voices = newNotes

proc noteOff*(instrument: var Instrument, note: int) =
    assert note >= 0 and note < 128
    # echo "Note off: ", note
    for i in 0..<instrument.voices.len:
        if instrument.voices[i].note == note:
            instrument.voices[i].synth.release()

proc noteOn*(instrument: var Instrument, note: int, velocity: float32) =
    assert note >= 0 and note < 128
    # echo "Note on: ", note, " ", velocity
    instrument.noteOff(note)
    let synth = newAudioSynth(440.0 * pow(2, (note-69).float32/12), velocity)
    instrument.voices.add((note: note, synth: synth))

proc controlMessage*(instrument: var Instrument, control: int, value: int) =
    let mval = max(0, value)
    # if control == 1:
    #     instrument.adsr.attack = mval.float32 / 127.0 * 0.05
    # elif control == 2:
    #     instrument.adsr.decay = mval.float32 / 127.0 * 0.2
    # elif control == 4:
    #     instrument.adsr.sustain = mval.float32 / 127.0
    # elif control == 12:
    #     instrument.adsr.release = mval.float32 / 127.0
    if control == 0x00:
        # bank select
        discard
    elif control == 0x01:
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
        if not instrument.voices[i].synth.finished:
            result += instrument.voices[i].synth.render() * instrument.volume
        else:
            cleanup = true
    if cleanup:
        instrument.stopInactiveNotes()
