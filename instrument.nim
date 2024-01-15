import std/[math, sequtils, strformat]
import audiosynth

type Instrument* = ref object
    voices: seq[tuple[note: int, synth: AudioSynth]]
    volume: float32
    reference: AudioSynth

proc newInstrument*(): Instrument =
    result = Instrument()
    result.volume = 1.0
    result.reference = newAudioSynth(440.0, 1.0)

proc stopInactiveNotes(instrument: var Instrument) =
    # Sort voices so that finished voices are at the end
    # Then remove them by setting the length of the sequence to the index of the first finished voice
    var a = 0
    var b = instrument.voices.len - 1
    while a < b:
        while a < b and not instrument.voices[a].synth.finished:
            inc a
        while a < b and instrument.voices[b].synth.finished:
            dec b
        if a < b:
            swap(instrument.voices[a], instrument.voices[b])
            inc a
            dec b
    instrument.voices.setLen(b + 1)

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
        var synth = instrument.reference.spawnFrom()
        synth.osc.frequency = 440.0 * pow(2, (note-69).float32/12)
        synth.osc.amplitude = velocity

        instrument.voices.add((note: note, synth: synth))

proc setParameter*(instrument: var Instrument, parameter: int, value: float32) =
    if parameter == 0:
        instrument.reference.adsr.attack = value
    elif parameter == 1:
        instrument.reference.adsr.decay = value
    elif parameter == 2:
        instrument.reference.adsr.sustain = value
    elif parameter == 3:
        instrument.reference.adsr.release = value
    elif parameter == 8:
        instrument.volume = value

proc controlMessage*(instrument: var Instrument, control: int, value: int) =
    let mval = max(0, value)
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
