import raylib, std/[sequtils, math, random, os]
import audiosynth
import instrument
import ringbuf16

const MaxSamplesPerUpdate = 4096

type AudioEngine = object
    initialized: bool
    stream: AudioStream
    instrument: Instrument
    limiter: float32
    backBuffer: RingBuffer16

var audioEngine: AudioEngine

proc noteOn*(note: int, velocity: float32) =
    audioEngine.instrument.noteOn(note, velocity)

proc noteOff*(note: int) =
    audioEngine.instrument.noteOff(note)

proc controlMessage*(control: int, value: int) =
    # echo control, " ", value
    audioEngine.instrument.controlMessage(control, value)

proc startAudioEngine*() =
    doAssert not audioEngine.initialized
    audioEngine.initialized = true
    audioEngine.limiter = 1.0

    initAudioDevice()
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)

    audioEngine.stream = loadAudioStream(48000, 16, 1)
    audioEngine.instrument = newInstrument()

    proc audioInputCallback(buffer: pointer; frames: uint32) {.cdecl.} =
        let d = cast[ptr UncheckedArray[int16]](buffer)
        for i in 0..<frames:
            # Mix all running synths
            var sample: float32 = 0.0
            sample = audioEngine.instrument.render() * 32000.0

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
            sample *= 0.5
            d[i] = int16(sample)
            audioEngine.backBuffer.write(int16(sample))
        
    setAudioStreamCallback(audioEngine.stream, audioInputCallback)
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)
    playAudioStream(audioEngine.stream)

proc closeAudioEngine*() =
    echo "Shutting down audio engine"
    closeAudioDevice()

proc readBackBuffer*(loc: int): int16 =
    audioEngine.backBuffer.read(loc)
