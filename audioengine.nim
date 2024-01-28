import raylib, std/[sequtils, strutils, strformat, math, random, os, locks, sets]
import audiosynth
import instrument
import ringbuf16
import midi/[midievents, encoders]

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
# var midiParameters: Channel[(int, int)]

proc sendCommand*(cmd: MidiEvent) =
    var ok = midiCommands.trySend(cmd)
    if not ok:
        echo "Audio engine command queue full"

proc handlePendingCommands() =
    # const bindPorts = [24, 25, 26, 27, 28, 29, 30, 31]
    # const bindPortsSet = bindPorts.toHashSet()
    # Read pending MIDI messages
    var loops = 0
    while true:
        let (ok, msg) = midiCommands.tryRecv()
        if ok and loops < 64:
            var ai = audioEngine.instrument
            if msg.kind == NoteOn:
                ai.noteOn(msg.param[0].int, msg.param[1].float32 / 127.0)
            if msg.kind == NoteOff:
                ai.noteOff(msg.param[0].int)
            if msg.kind == ControlChange:
                # echo "Control change: ", msg.param[0].int, " ", msg.param[1].int
                audioEngine.instrument.controlMessage(msg.param[0].int, msg.param[1].int)
            inc loops
        else:
            break

proc renderMaster(): float32 =
    # Mix all running instruments
    result = audioEngine.instrument.render() * 32000.0

    # Simple limiter
    result *= audioEngine.limiter
    if result.abs > 32000.0:
        let correction = 32000.0 / result.abs
        audioEngine.limiter *= correction
        result *= correction

    if audioEngine.limiter < 1.0:
        audioEngine.limiter += 0.00001
        audioEngine.limiter = min(audioEngine.limiter, 1.0)

proc startAudioEngine*() =
    if audioEngine.initialized:
        assert false, "Audio engine already initialized"
        return

    audioEngine.initialized = true
    audioEngine.limiter = 1.0
    audioEngine.volume = 1.0

    midiCommands.open(256)

    initAudioDevice()
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)

    audioEngine.stream = loadAudioStream(48000, 16, 1)
    audioEngine.instrument = newInstrument()

    proc audioInputCallback(buffer: pointer; frames: uint32) {.cdecl.} =
        handlePendingCommands()

        # Render to audio buffer
        let d = cast[ptr UncheckedArray[int16]](buffer)
        for i in 0..<frames:
            let sample = renderMaster() * audioEngine.volume
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
