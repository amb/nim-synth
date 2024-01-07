import raylib, std/[sequtils, math]
import audiosynth

const
    MaxSamplesPerUpdate = 4096

type AudioEngine = object
    initialized: bool
    stream: AudioStream
    synths: seq[AudioSynth]
    channels: seq[AudioSynth]
    limiter: float32
    backBuffer: seq[int16]

var audioEngine: AudioEngine

proc synthCounts*(): (int, int) =
    return (audioEngine.synths.len, audioEngine.synths.countIt(it.active))

proc stopInactiveSynths*() =
    var newSynths: seq[AudioSynth]
    for synth in audioEngine.synths:
        if synth.active:
            newSynths.add(synth)
    audioEngine.synths = newSynths

proc addSynth*(channel: int, synth: AudioSynth) =
    audioEngine.synths.add(synth)
    audioEngine.channels[channel] = synth

proc channelMessage*(channel: int, message: ControlMessage) =
    doAssert channel >= 0 and channel < audioEngine.channels.len
    audioEngine.channels[channel].message(message)

proc startAudioEngine*() =
    doAssert not audioEngine.initialized
    audioEngine.initialized = true
    audioEngine.limiter = 1.0

    initAudioDevice()
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)

    audioEngine.stream = loadAudioStream(48000, 16, 1)
    audioEngine.backBuffer = newSeq[int16](65536)
    audioEngine.channels = newSeq[AudioSynth](128)

    proc audioInputCallback(buffer: pointer; frames: uint32) {.cdecl.} =
        let d = cast[ptr UncheckedArray[int16]](buffer)
        var cleanup = false

        for i in 0..<frames:
            # Mix all running synths
            var sample: float32 = 0.0
            for si in 0..<audioEngine.synths.len:
                if audioEngine.synths[si].active:
                    sample += 32000'f32 * audioEngine.synths[si].render()
                else:
                    cleanup = true

            # Simple limiter
            sample *= audioEngine.limiter
            if sample.abs > 32000.0:
                let correction = 32000.0 / sample.abs
                audioEngine.limiter *= correction
                sample *= correction

            if audioEngine.limiter < 1.0:
                audioEngine.limiter += 0.00001
                audioEngine.limiter = min(audioEngine.limiter, 1.0)

            # Output sample
            d[i] = int16(sample)

        if cleanup:
            stopInactiveSynths()

    setAudioStreamCallback(audioEngine.stream, audioInputCallback)
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)
    playAudioStream(audioEngine.stream)

proc closeAudioEngine*() =
    echo "Shutting down audio engine"
    closeAudioDevice()
