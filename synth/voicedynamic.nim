import audiosynth

type VoiceDynamic* = ref object
    voices: seq[tuple[note: int, synth: AudioSynth]]
    reference: AudioSynth
    volume: float32

proc newVoiceDynamic*(): VoiceDynamic =
    result = VoiceDynamic()
    result.volume = 1.0
    result.reference = newAudioSynth(0.0, 1.0, 48000.0)

proc stopInactiveNotes(vdyn: var VoiceDynamic) =
    # Sort voices in-place so that finished voices are at the end
    # Then remove them by setting the length of the sequence to the index of the first finished voice
    var a = 0
    var b = vdyn.voices.len - 1
    while a < b:
        while a < b and not vdyn.voices[a].synth.isFinished():
            inc a
        while a < b and vdyn.voices[b].synth.isFinished():
            dec b
        if a < b:
            swap(vdyn.voices[a], vdyn.voices[b])
            inc a
            dec b
    vdyn.voices.setLen(b + 1)

proc noteOff*(vdyn: var VoiceDynamic, note: int) =
    assert note >= 0 and note < 128
    for i in 0..<vdyn.voices.len:
        if vdyn.voices[i].note == note:
            vdyn.voices[i].synth.release()

proc noteOn*(vdyn: var VoiceDynamic, note: int, velocity: float32) =
    assert note >= 0 and note < 128
    vdyn.noteOff(note)

    # NOTE: some midi files send note on with velocity 0 to stop a note
    if velocity > 0.0:
        var synth = vdyn.reference.spawnFrom()
        synth.setNote(note.float32, velocity)
        vdyn.voices.add((note: note, synth: synth))

proc render*(vdyn: var VoiceDynamic): float32 =
    var cleanup = false
    for i in 0..<vdyn.voices.len:
        if not vdyn.voices[i].synth.isFinished():
            result += vdyn.voices[i].synth.render() * vdyn.volume
        else:
            cleanup = true
    if cleanup:
        vdyn.stopInactiveNotes()
