import std/[sequtils, strutils, math, strformat, os, bitops, sets, tables]
import raylib
import rtmidi
import midi/[midievents, encoders]
import audioengine
import instrument
import audiosynth
import keyboardinput

const
    screenWidth = 800
    screenHeight = 450

proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    if midiMsg.len > 0:
        audioengine.sendCommand(midiMsg.makeMidiEvent())

proc drawKnob(x: int32, y: int32, value: float32, txt: cstring, up: int32, fnt: Font) =
    let center = Vector2(x: x.float32, y: y.float32)
    drawRing(center, 14.0, 20.0, 0.0, clamp(value * 360.0, 10.0, 360.0), 16, Black)
    let l1 = Vector2(x: (x + 19).float32, y: (y).float32)
    let l2 = Vector2(x: (x + 19).float32, y: (y - 24 - up).float32)
    let l3 = Vector2(x: (x - 19).float32, y: (y - 24 - up).float32)
    drawLine(l1, l2, 2.0, Black)
    drawLine(l2, l3, 2.0, Black)
    let bigness: int32 = 20
    let b2 = bigness div 2
    drawText(($int(value*99)).cstring, x-b2-1, y-b2+1, bigness, Black)
    drawText(txt, x-16, y-44-up, 20, Black)

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

    var synthParams: array[SynthParamKind, EncoderInput] = audioEngine.getInstrument().getInstrumentParamList()

    for k, v in synthParams.pairs:
        echo fmt"{k}: {v}"

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

        var locX: int32 = 0
        for k, v in synthParams.pairs:
            drawKnob(50 + (locX.floorMod(8)) * 50, 180 + (locX div 8) * 120, v.normalized(), 
                k.repr.cstring, 40 - 20 * (locX.floorMod(3)), fontPixantiqua)
            inc locX
        # drawKnob(50, 100, 0.3, "Foo1Bar".cstring, 20, fontPixantiqua)

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
