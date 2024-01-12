import raylib, std/[sequtils, strutils, math, random, os, locks]
import audiosynth
import instrument
import ringbuf16
import midi/midievents

const MaxSamplesPerUpdate = 64

type AudioEngine = object
    stream: AudioStream
    instrument: Instrument
    backBuffer: RingBuffer16
    limiter: float32
    volume: float32
    initialized: bool

var audioEngine: AudioEngine
var midiCommands: Channel[MidiEvent]

proc sendCommand*(cmd: MidiEvent) =
    doAssert cmd.kind != Undefined
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
        while true:
            let (ok, msg) = midiCommands.tryRecv()
            if ok:
                var ai = audioEngine.instrument
                if msg.kind == NoteOn:
                    ai.noteOn(msg.param[0].int, msg.param[1].float32 / 127.0)
                if msg.kind == NoteOff:
                    ai.noteOff(msg.param[0].int)
                if msg.kind == ControlChange:
                    ai.controlMessage(msg.param[0].int, msg.param[1].int)
            else:
                break

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
