import std/[math, sequtils, strformat]
import audiosynth

type Instrument* = ref object
    voices: seq[tuple[note: int, synth: AudioSynth]]
    volume: float32

proc newInstrument*(): Instrument =
    result = Instrument()
    result.volume = 1.0

proc stopInactiveNotes(instrument: var Instrument) =
    # Sort voices so that finished voices are at the end
    # Then remove them by setting the length of the sequence to the index of the first finished voice
    var a = 0
    var b = instrument.voices.len - 1
    
    # let startNodes = instrument.voices.len
    # let finishedNotes = instrument.voices.countIt(it.synth.finished)
    
    while a < b:
        while a < b and not instrument.voices[a].synth.finished:
            inc a
        while a < b and instrument.voices[b].synth.finished:
            dec b
        if a < b:
            swap(instrument.voices[a], instrument.voices[b])
            inc a
            dec b
    # let stillRunning = instrument.voices.countIt(not it.synth.finished)
    instrument.voices.setLen(b + 1)

    # let t1 = instrument.voices.len == startNodes - finishedNotes
    # let t2 = instrument.voices.countIt(it.synth.finished) == 0
    # if not t1 or not t2:
    #     echo fmt"failure: {startNodes} -> {instrument.voices.len}, {finishedNotes} -> {instrument.voices.countIt(it.synth.finished)}"

proc noteOff*(instrument: var Instrument, note: int) =
    assert note >= 0 and note < 128
    for i in 0..<instrument.voices.len:
        if instrument.voices[i].note == note:
            instrument.voices[i].synth.release()

proc noteOn*(instrument: var Instrument, note: int, velocity: float32) =
    assert note >= 0 and note < 128
    instrument.noteOff(note)

    # NOTE: some midi files send note on with velocity 0 to stop a note
    if velocity > 0.0:
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
