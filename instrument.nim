import std/[math, tables, sequtils, strformat, sets]
import audiosynth
import audiocomponent
import midi/encoders

type Instrument* = ref object
    voices: seq[tuple[note: int, synth: AudioSynth]]
    volume: float32
    reference: AudioSynth
    # knobs: array[8, EncoderInput]

proc newInstrument*(): Instrument =
    result = Instrument()
    result.volume = 1.0
    result.reference = newAudioSynth(0.0, 1.0, 48000.0)

proc stopInactiveNotes(instrument: var Instrument) =
    # Sort voices in-place so that finished voices are at the end
    # Then remove them by setting the length of the sequence to the index of the first finished voice
    var a = 0
    var b = instrument.voices.len - 1
    while a < b:
        while a < b and not instrument.voices[a].synth.component.isFinished():
            inc a
        while a < b and instrument.voices[b].synth.component.isFinished():
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
        synth.setNote(note.float32, velocity)
        instrument.voices.add((note: note, synth: synth))

proc controlMessage*(instrument: var Instrument, control: int, value: int) =
    # TODO: not exactly according to the MIDI spec
    const mapping = {
        24: "osc1.feedback",
        25: "osc2.amp",
        26: "oscRatio",
        27: "adsr2.attack",
        28: "adsr1.attack",
        29: "adsr1.release",
        30: "lowpass.resonance",
        31: "lowpass.cutoff"
    }.toTable

    if control in mapping:
        instrument.reference.nudgeParam(mapping[control], value)
    elif control == 0x00:
        # bank select
        echo "Unhandled: bank select"
    elif control == 0x01:
        # modulation
        echo "Unhandled: modulation"
    elif control == 0x05:
        # TODO: finish
        # portamento time
        echo "Unhandled: portamento time"
    elif control == 0x06:
        # data entry (MSB)
        echo "Unhandled: data entry (MSB)"
    elif control == 0x07:
        # volume
        instrument.volume = max(0, value).float32 / 127.0
    elif control == 0x0A:
        # pan
        echo "Unhandled: pan"
    elif control == 0x0B:
        # expression
        echo "Unhandled: expression"
    elif control == 0x41:
        # portamento
        echo "Unhandled: portamento"
    else:
        echo "Unhandled control event: ", control, " ", value

proc render*(instrument: var Instrument): float32 =
    var cleanup = false
    for i in 0..<instrument.voices.len:
        if not instrument.voices[i].synth.component.isFinished():
            result += instrument.voices[i].synth.render() * instrument.volume
        else:
            cleanup = true
    if cleanup:
        instrument.stopInactiveNotes()
