import raylib, std/[sequtils, math, random, os]
import audiosynth

const MaxSamplesPerUpdate = 4096

type RingBuffer16 = object
    buffer: array[65536, int16]
    position: uint16

proc write*(rb: var RingBuffer16, sample: int16) =
    rb.buffer[rb.position] = sample
    inc rb.position

proc read*(rb: RingBuffer16, rewind: int): int16 =
    var pos: int = rb.position.int - rewind
    if pos < 0:
        pos += rb.buffer.len
    assert pos >= 0 and pos < rb.buffer.len
    return rb.buffer[pos]

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

proc startAudioEngine*() =
    doAssert not audioEngine.initialized
    audioEngine.initialized = true
    audioEngine.limiter = 1.0

    initAudioDevice()
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)

    audioEngine.stream = loadAudioStream(48000, 16, 1)

    doAssert isAudioStreamReady(audioEngine.stream)

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
