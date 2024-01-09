import raylib, std/[sequtils, math, random, os]
import audiosynth
import instrument
import ringbuf16

const MaxSamplesPerUpdate = 128

type AudioEngine = object
    stream: AudioStream
    instrument: Instrument
    backBuffer: RingBuffer16
    limiter: float32
    volume: float32
    initialized: bool

var audioEngine: AudioEngine
var midiCommands: Channel[array[4, byte]]

proc sendCommand*(cmd: array[4, byte]) =
    var ok = midiCommands.trySend(cmd)
    if not ok:
        echo "Audio engine command queue full"

proc startAudioEngine*() =
    doAssert not audioEngine.initialized
    audioEngine.initialized = true
    audioEngine.limiter = 1.0
    audioEngine.volume = 0.5
    midiCommands.open(256)

    initAudioDevice()
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)

    audioEngine.stream = loadAudioStream(48000, 16, 1)
    audioEngine.instrument = newInstrument()

    proc audioInputCallback(buffer: pointer; frames: uint32) {.cdecl.} =
        # Read pending MIDI messages
        let (ok, midiMsg) = midiCommands.tryRecv()
        if ok:
            let command = midiMsg[0] shr 4
            let channel = midiMsg[0] and 0x0F

            # Note on
            if command == 0x9:
                audioEngine.instrument.noteOn(midiMsg[1].int, (midiMsg[2].int).float32 / 127.0)
            # Note off
            elif command == 0x8:
                audioEngine.instrument.noteOff(midiMsg[1].int)
            # Control message
            elif command == 0xB:
                audioEngine.instrument.controlMessage(midiMsg[1].int, midiMsg[2].int)

        # Render to audio buffer
        let d = cast[ptr UncheckedArray[int16]](buffer)
        for i in 0..<frames:
            # Mix all running instruments
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
            sample *= audioEngine.volume
            d[i] = int16(sample)
            audioEngine.backBuffer.write(int16(sample))
        
    setAudioStreamCallback(audioEngine.stream, audioInputCallback)
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)
    playAudioStream(audioEngine.stream)

proc closeAudioEngine*() =
    echo "Shutting down audio engine"
    closeAudioDevice()
    midiCommands.close()

proc readBackBuffer*(loc: int): int16 =
    audioEngine.backBuffer.read(loc)
