import raylib, std/[sequtils, strutils, math, strformat, os, bitops]
import rtmidi
import midi/midievents
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

proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    if midiMsg.len > 0:
        assert midiMsg.len == 4
        var outMsg: array[4, byte]
        for i in 0..<4:
            outMsg[i] = midiMsg[i]
        audioengine.sendCommand(outMsg.makeMidiEvent())

proc main =
    initWindow(screenWidth, screenHeight, "Simple synth")
    defer: closeWindow()

    startAudioEngine()
    defer: closeAudioEngine()

    var fontPixantiqua = loadFont("res/pixantiqua.ttf")

    # Init MIDI inputs
    var devIn = initMidiIn()
    devIn.openPort(1)
    devIn.setCallback(midiInCallback)

    echo "MIDI ports:"
    for i in 0..<devIn.portCount():
        echo "Port #", i, ": ", devIn.portName(i)

    # TODO: proper quick keyboard polling

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
            audioengine.sendCommand([0x80.byte, (n+36).byte, 0.byte, 0.byte].makeMidiEvent())
        
        for n in getPressedNotes():
            audioengine.sendCommand([0x90.byte, (n+36).byte, 127.byte, 0.byte].makeMidiEvent())

        sleep(2)

main()
