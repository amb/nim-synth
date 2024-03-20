import audiosynth

const MAX_POLYPHONY = 8

type VoiceStatic* = ref object
    voices: array[MAX_POLYPHONY, tuple[note: int, synth: AudioSynth]]
    reference*: AudioSynth

proc newVoiceStatic*(): VoiceStatic =
    result = VoiceStatic()
    result.reference = newAudioSynth(0.0, 1.0, 48000.0)
    for i in 0..<MAX_POLYPHONY:
        result.voices[i].synth = result.reference.spawnFrom()
        # Don't start playing immediately
        result.voices[i].synth.finish()

proc noteOff*(vdyn: var VoiceStatic, note: int) =
    assert note >= 0 and note < 128
    for i in 0..<MAX_POLYPHONY:
        if vdyn.voices[i].note == note:
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
        for i in 0..<MAX_POLYPHONY:
            if vdyn.voices[i].synth.isReleased():
                voiceLoc = i
                break
        vdyn.voices[voiceLoc].note = note
        vdyn.voices[voiceLoc].synth = synth

proc render*(vdyn: var VoiceStatic): float32 =
    for i in 0..<MAX_POLYPHONY:
        result += vdyn.voices[i].synth.render()

proc setAllParams*(vdyn: var VoiceStatic, name: string, value: float32) =
    vdyn.reference.setParam(name, value)
    for i in 0..<MAX_POLYPHONY:
        vdyn.voices[i].synth.setParam(name, value)
