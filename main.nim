import std/[sequtils, strutils, math, strformat, os, bitops, sets]
import raylib
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
        audioengine.sendCommand(midiMsg.makeMidiEvent())

proc midiInCallbackCC(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    echo "CC: ", midiMsg
    const bindPorts = [74, 71, 65, 2,  5,  76, 77, 78, 10, 73, 75, 72, 91, 92, 93, 94, 95, 7]
    const bindPortsSet = bindPorts.toSet()
    if midiMsg[0] == 176:
        if midiMsg[1].int in bindPortsSet:
            audioengine.sendParameter(bindPorts.find(midiMsg[1].int), midiMsg[2].float32 / 127.0)

proc main =
    # TODO: make this a proper config

    initWindow(screenWidth, screenHeight, "Simple synth")
    defer: closeWindow()

    startAudioEngine()
    defer: closeAudioEngine()

    var fontPixantiqua = loadFont("res/pixantiqua.ttf")
    # guiSetFont(fontPixantiqua)

    # Init MIDI inputs
    var devIn = initMidiIn()
    var ccIn = initMidiIn()
    if devIn.portCount() > 0:
        devIn.openPort(1)
        ccIn.openPort(2)
        devIn.setCallback(midiInCallback)
        ccIn.setCallback(midiInCallbackCC)

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

        # drawText(fontPixantiqua, cstring($getFPS()), Vector2(x: 10.0 , y: 10.0), fontPixantiqua.baseSize.float32, 4.0, Red)
        drawText(cstring($getFPS()), 10, 10, 32, Red)

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
            audioengine.sendCommand([0x80, (n+36), 0, 0].makeMidiEvent())

        for n in getPressedNotes():
            audioengine.sendCommand([0x90, (n+36), 127, 0].makeMidiEvent())

        sleep(2)

main()
