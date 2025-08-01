import raylib, std/[sequtils, strutils, strformat, math, random, os, locks, sets, monotimes]
import ../midi/[midievents, encoders]
import components/[limiter, reverb, ringbuf]
import audiosynth
import instrument
import voicestatic

const MaxSamplesPerUpdate = 64

# TODO: separate instrument from audioengine, use separate path to message synth
#       create function to add audio producers etc.

type AudioEngine = object
    stream: AudioStream
    instrument: Instrument
    backBuffer: RingBuffer[65536, int16]
    limiter: Limiter
    reverb: Reverb
    initialized: bool
    frameTime: int64

var audioEngine: AudioEngine
var midiCommands: Channel[MidiEvent]

proc getInstrument*(): Instrument = audioEngine.instrument

proc setMapping*(midi: int, param: string) =
    audioEngine.instrument.setMapping(midi, param)

proc frameTime*(): int64 = audioEngine.frameTime

proc sendCommand*(cmd: MidiEvent) =
    var ok = midiCommands.trySend(cmd)
    if not ok:
        echo "Audio engine command queue full"

proc handlePendingCommands() =
    # Read pending MIDI messages
    var loops = 0
    while true:
        let (ok, msg) = midiCommands.tryRecv()
        if ok and loops < 64:
            var ai = audioEngine.instrument
            if msg.kind == NoteOn:
                ai.machine.noteOn(msg.param[0].int, msg.param[1].float32 / 127.0)
            if msg.kind == NoteOff:
                ai.machine.noteOff(msg.param[0].int)
            if msg.kind == ControlChange:
                ai.controlMessage(msg.param[0].int, msg.param[1].int)
            inc loops
        else:
            break

proc renderMaster(): (float32, float32) =
    # Mix all running instruments
    var sample = audioEngine.instrument.machine.render()

    # Effect chain
    result = audioEngine.reverb.renderStereo(sample)

    # Simple limiter
    result = audioEngine.limiter.renderStereo(result)

    # result = audioEngine.limiter.renderStereo((sample, sample))

proc startAudioEngine*() =
    if audioEngine.initialized:
        assert false, "Audio engine already initialized"
        return

    audioEngine.initialized = true
    audioEngine.limiter = newLimiter(0.95, 0.001)

    midiCommands.open(256)

    initAudioDevice()
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)

    audioEngine.stream = loadAudioStream(48000, 16, 2)
    audioEngine.instrument = newInstrument()
    audioEngine.reverb = newReverb()

    proc audioInputCallback(buffer: pointer; frames: uint32) {.cdecl.} =
        handlePendingCommands()

        let startTime = monotimes.getMonoTime().ticks()

        # Render to audio buffer
        let d = cast[ptr UncheckedArray[int16]](buffer)
        for i in 0..<frames:
            let sample = renderMaster()
            let fl = int16(sample[0] * 32767.0)
            let fr = int16(sample[1] * 32767.0)
            d[i*2+0] = fl
            d[i*2+1] = fr
            audioEngine.backBuffer.write(fl)

        audioEngine.frameTime = (monotimes.getMonoTime().ticks() - startTime) div (frames.int64)

    setAudioStreamCallback(audioEngine.stream, audioInputCallback)
    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)
    playAudioStream(audioEngine.stream)

proc closeAudioEngine*() =
    echo "Shutting down audio engine"
    closeAudioDevice()
    midiCommands.close()

proc readBackBuffer*(loc: int): int16 =
    assert loc >= 0
    audioEngine.backBuffer.read(loc.uint16)
