import raylib, std/[sequtils, strutils, math, strformat, os]
import rtmidi
import audioengine
import audiosynth

const
    screenWidth = 800
    screenHeight = 450

const musicKeys1 = [
    KeyboardKey.Q, KeyboardKey.Two, KeyboardKey.W, KeyboardKey.Three, KeyboardKey.E, KeyboardKey.R, 
    KeyboardKey.Five, KeyboardKey.T, KeyboardKey.Six, KeyboardKey.Y, KeyboardKey.Seven, KeyboardKey.U,
    KeyboardKey.I, KeyboardKey.Nine, KeyboardKey.O, KeyboardKey.Zero, KeyboardKey.P
]

const musicKeys2 = [
    KeyboardKey.Z, KeyboardKey.S, KeyboardKey.X, KeyboardKey.D, KeyboardKey.C, KeyboardKey.V,
    KeyboardKey.G, KeyboardKey.B, KeyboardKey.H, KeyboardKey.N, KeyboardKey.J, KeyboardKey.M,
    KeyboardKey.Comma, KeyboardKey.L, KeyboardKey.Period
]

proc getPressedNotes(): seq[int] =
    for mk_id, mkey in musicKeys1:
        if isKeyPressed(mkey):
            result.add(mk_id + 12)

    for mk_id, mkey in musicKeys2:
        if isKeyPressed(mkey):
            result.add(mk_id)

proc getReleasedNotes(): seq[int] =
    for mk_id, mkey in musicKeys1:
        if isKeyReleased(mkey):
            result.add(mk_id + 12)

    for mk_id, mkey in musicKeys2:
        if isKeyReleased(mkey):
            result.add(mk_id)


# proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
#     stdout.write fmt"{timestamp:9.7f}: "
#     for b in midiMsg:
#         stdout.write b
#         stdout.write ' '

#     let messageText = case midiMsg[0]:
#         of 0x90: "Note On"
#         of 0x80: "Note Off"
#         of 0xB0: "Control Change"
#         of 0xC0: "Program Change"
#         of 0xE0: "Pitch Bend"
#         else: "Unknown"

#     stdout.write "  ", messageText
#     echo ""

#     if midiMsg[0] == 0x90:
#         let note = midiMsg[1].int
#         let velocity = midiMsg[2].int
#         addSynth(note, newAudioSynth(440.0 * pow(2, (note+12).float32/12)))
#     elif midiMsg[0] == 0x80:
#         let note = midiMsg[1].int
#         channelMessage(note, ControlMessage.Release)


proc main =
    initWindow(screenWidth, screenHeight, "Simple synth")
    defer: closeWindow()

    startAudioEngine()
    defer: closeAudioEngine()

    var fontPixantiqua = loadFont("res/pixantiqua.ttf")

    # Init MIDI inputs
    var devIn = initMidiIn()
    devIn.openPort(2)
    # devIn.setCallback(midiInCallback)

    echo "MIDI ports:"
    for i in 0..<devIn.portCount():
        echo "Port #", i, ": ", devIn.portName(i)

    # TODO: proper quick keyboard polling

    # setTargetFPS(60)
    var midiMsg: seq[byte]
    while not windowShouldClose():
        var mousePosition = getMousePosition()
        if isMouseButtonDown(Left):
            discard

        beginDrawing()
        clearBackground(RayWhite)

        drawText(fontPixantiqua, cstring($getFPS()), Vector2(x: 10.0 , y: 10.0), fontPixantiqua.baseSize.float32, 4.0, Red)

        # Draw the current buffer state proportionate to the screen
        for i in 0..<screenWidth:
            let x: int32 = i.int32
            # let y: int32 = 100 + 50*data[i*audioengine.MaxSamples div screenWidth] div 32000
            let y: int32 = 100 + 50 * readBackBuffer(i).int32 div 32000
            drawPixel(x, y, Red)
            drawPixel(x, y + 1, Red)
        endDrawing()

        # Interpret keyboard as keyboard
        for n in getReleasedNotes():
            # channelMessage(n, ControlMessage.Release)
            noteOff(n)
        
        for n in getPressedNotes():
            # addSynth(n, newAudioSynth(440.0 * pow(2, (n-9).float32/12), 1.0))
            noteOn(n, 0.9)

        # Read MIDI messages
        var midiTimeStamp = devIn.recvMidi(midiMsg)
        if midiMsg.len > 0:
            if midiMsg[0] == 0x90:
                let note = midiMsg[1].int
                let velocity = midiMsg[2].int
                # addSynth(note, newAudioSynth(440.0 * pow(2, (note-69).float32/12), velocity.float32 / 127.0))
                noteOn(note, velocity.float32 / 127.0)
            elif midiMsg[0] == 0x80:
                let note = midiMsg[1].int
                # channelMessage(note, ControlMessage.Release)
                noteOff(note)

        midiMsg.setLen(0)

        sleep(2)

main()
