import raylib, std/[sequtils, math, sets]
import audiosynth

const
    MaxSamples = 512
    MaxSamplesPerUpdate = 4096

type AudioEngine = object
    initialized: bool
    stream: AudioStream
    data: seq[int16]
    synths: seq[AudioSynth]
    limiter: float32

var audioEngine: AudioEngine

proc synthCounts*(): (int, int) =
    return (audioEngine.synths.len, audioEngine.synths.countIt(it.active))

proc stopInsynths*() =
    var newSynths: seq[AudioSynth]
    for synth in audioEngine.synths:
        if synth.active:
            newSynths.add(synth)
    audioEngine.synths = newSynths

proc addSynth*(synth: AudioSynth) =
    stopInsynths()
    audioEngine.synths.add(synth)

proc startAudioEngine*() =
    doAssert not audioEngine.initialized
    audioEngine.initialized = true
    audioEngine.limiter = 1.0

    initAudioDevice()
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)
 
    audioEngine.stream = loadAudioStream(48000, 16, 1)
    audioEngine.data = newSeq[int16](MaxSamples)

    proc audioInputCallback(buffer: pointer; frames: uint32) {.cdecl.} =
        let d = cast[ptr UncheckedArray[int16]](buffer)
        for si in 0..<audioEngine.synths.len:
            if audioEngine.synths[si].active:
                for i in 0..<frames:
                    var sample: float32 = d[i].float32 + 32000'f32 * audioEngine.limiter * audioEngine.synths[si].render()
                    if sample.abs > 32000.0:
                        var correction = 32000.0 / sample.abs
                        audioEngine.limiter *= correction
                        sample *= correction
                    d[i] = int16(sample)

        if audioEngine.limiter < 1.0:
            audioEngine.limiter += 0.01
            audioEngine.limiter = min(audioEngine.limiter, 1.0)

    setAudioStreamCallback(audioEngine.stream, audioInputCallback)
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)
    playAudioStream(audioEngine.stream)

proc closeAudioEngine*() =
    echo "Shutting down audio engine"
    closeAudioDevice()
