import audiosynth

type VoiceStatic* = ref object
    voices: array[8, tuple[note: int, synth: AudioSynth]]
    voiceLoc: int
    reference*: AudioSynth
    volume*: float32

proc newVoiceStatic*(): VoiceStatic =
    echo "nVS"
    result = VoiceStatic()
    result.volume = 1.0
    result.voiceLoc = 0
    result.reference = newAudioSynth(0.0, 1.0, 48000.0)
    # for i in 0..<result.voices.len:
    #     result.voices[i].synth = newAudioSynth(0.0, 1.0, 48000.0)
    #     result.voices[i].synth.finish()

proc noteOff*(vdyn: var VoiceStatic, note: int) =
    assert note >= 0 and note < 128
    for i in 0..<vdyn.voices.len:
        if vdyn.voices[i].note == note:
            vdyn.voices[i].synth.release()

proc noteOn*(vdyn: var VoiceStatic, note: int, velocity: float32) =
    assert note >= 0 and note < 128
    vdyn.noteOff(note)

    # NOTE: some midi files send note on with velocity 0 to stop a note
    if velocity > 0.0:
        var synth = vdyn.reference.spawnFrom()
        synth.setNote(note.float32, velocity)
        vdyn.voices[vdyn.voiceLoc].note = note
        vdyn.voices[vdyn.voiceLoc].synth = synth
        inc vdyn.voiceLoc
        if vdyn.voiceLoc >= vdyn.voices.len:
            vdyn.voiceLoc = 0

proc render*(vdyn: var VoiceStatic): float32 =
    for i in 0..<vdyn.voices.len:
        result += vdyn.voices[i].synth.render() * vdyn.volume
