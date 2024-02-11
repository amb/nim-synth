import audiosynth

type VoiceStatic* = ref object
    voices: array[8, tuple[note: int, synth: AudioSynth]]
    reference*: AudioSynth

proc newVoiceStatic*(): VoiceStatic =
    result = VoiceStatic()
    result.reference = newAudioSynth(0.0, 1.0, 48000.0)
    for i in 0..<result.voices.len:
        result.voices[i].note = -1

proc noteOff*(vdyn: var VoiceStatic, note: int) =
    assert note >= 0 and note < 128
    for i in 0..<vdyn.voices.len:
        if vdyn.voices[i].note == note:
            vdyn.voices[i].note = -1
            vdyn.voices[i].synth.release()

proc noteOn*(vdyn: var VoiceStatic, note: int, velocity: float32) =
    assert note >= 0 and note < 128
    vdyn.noteOff(note)

    # NOTE: some midi files send note on with velocity 0 to stop a note
    # TODO: find the unused note with the longest history
    if velocity > 0.0:
        var synth = vdyn.reference.spawnFrom()
        synth.setNote(note.float32, velocity)
        var voiceLoc = 0
        for i in 0..<vdyn.voices.len:
            if vdyn.voices[i].note == -1:
                voiceLoc = i
                echo "voiceLoc: ", voiceLoc
                break
        vdyn.voices[voiceLoc].note = note
        vdyn.voices[voiceLoc].synth = synth

proc render*(vdyn: var VoiceStatic): float32 =
    for i in 0..<vdyn.voices.len:
        result += vdyn.voices[i].synth.render()
