import raylib, std/[sequtils, math]
import audiosynth

const MaxSamplesPerUpdate = 4096

type AudioEngine = object
    initialized: bool
    stream: AudioStream
    instrument: Instrument
    limiter: float32
    backBuffer: seq[int16]

var audioEngine: AudioEngine

proc noteOn*(note: int, velocity: float32) =
    audioEngine.instrument.noteOn(note, velocity)

proc noteOff*(note: int) =
    audioEngine.instrument.noteOff(note)

proc startAudioEngine*() =
    doAssert not audioEngine.initialized
    audioEngine.initialized = true
    audioEngine.limiter = 1.0

    initAudioDevice()
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)

    audioEngine.stream = loadAudioStream(48000, 16, 1)
    audioEngine.backBuffer = newSeq[int16](65536)
    audioEngine.instrument = newInstrument()

    proc audioInputCallback(buffer: pointer; frames: uint32) {.cdecl.} =
        let d = cast[ptr UncheckedArray[int16]](buffer)
        for i in 0..<frames:
            # Mix all running synths
            var sample: float32 = 0.0
            # for si in 0..<audioEngine.synths.len:
            #     if not audioEngine.synths[si].finished:
            #         sample += 32000'f32 * audioEngine.synths[si].render()
            #     else:
            #         cleanup = true

            sample = audioEngine.instrument.render()

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

    setAudioStreamCallback(audioEngine.stream, audioInputCallback)
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)
    playAudioStream(audioEngine.stream)

proc closeAudioEngine*() =
    echo "Shutting down audio engine"
    closeAudioDevice()
