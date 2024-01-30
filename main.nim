import std/[sequtils, strutils, math, strformat, os, bitops, sets]
import raylib
import rtmidi
import midi/[midievents]
import audioengine
import audiosynth
import keyboardinput

const
    screenWidth = 800
    screenHeight = 450

proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    if midiMsg.len > 0:
        audioengine.sendCommand(midiMsg.makeMidiEvent())

proc main =
    # TODO: make this a proper config

    initWindow(screenWidth, screenHeight, "Simple synth")
    defer: closeWindow()

    startAudioEngine()
    defer: closeAudioEngine()

    var fontPixantiqua = loadFont("res/pixantiqua.ttf")
    # guiSetFont(fontPixantiqua)

    var devIn = initMidiIn()
    if devIn.portCount() > 0:
        devIn.openPort(0)
        devIn.setCallback(midiInCallback)
    echo "MIDI ports:"
    for i in 0..<devIn.portCount():
        echo "Port #", i, ": ", devIn.portName(i)

    var counter: uint8 = 0

    var fpsText: cstring = ""
    var frameTimeText: cstring = ""

    while not windowShouldClose():
        var mousePosition = getMousePosition()
        if isMouseButtonDown(Left):
            discard

        beginDrawing()
        clearBackground(RayWhite)

        if counter == 0:
            fpsText = cstring($fmt"{getFPS()} fps")
            frameTimeText = cstring(fmt"{audioEngine.frameTime().float32/1000.0:.2f} 10e-6 s")

        # drawText(fontPixantiqua, cstring($getFPS()), Vector2(x: 10.0 , y: 10.0), fontPixantiqua.baseSize.float32, 4.0, Red)
        drawText(fpsText, 10, 10, 32, Red)
        drawText(frameTimeText, 10, 40, 32, Red)

        # Draw the current buffer state proportionate to the screen
        for i in 0..<screenWidth:
            let x: int32 = i.int32
            let y: int32 = screenHeight - 55 + 50 * readBackBuffer(i).int32 div 32000
            drawPixel(x, y, Red)
            drawPixel(x, y + 1, Red)
        endDrawing()

        for msg in readKeys():
            audioengine.sendCommand(msg)

        sleep(2)

        inc counter

main()
