import std/[sequtils, strutils, math, strformat, os, bitops, sets, tables, enumerate]
import raylib, raymath
import external/rtmidi
import midi/[midievents, encoders]
import synth/[audiosynth, instrument, audioengine]
import keyboardinput
import gui

const
    screenWidth = 800
    screenHeight = 600

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

    var synthParams: array[SynthParamKind, EncoderInput] = audioEngine.getInstrument().getInstrumentParamList()

    let ccOffset = 24

    for e, (k, v) in enumerate(synthParams.pairs):
        # TODO: generate from actual config
        audioEngine.setMapping(k.ord + ccOffset, k)

    var mouseAdjusting = false
    var mouseKnob: int = -1
    var prevAngle: float32 = 0.0
    while not windowShouldClose():
        # click/drag to adjust
        var mousePosition = getMousePosition()
        if isMouseButtonDown(Left):
            if mouseAdjusting:
                let i = 0
                let value = 1.0
                audioEngine.sendCommand(makeMidiEvent([0xB0, ccOffset + i.int32, (value * 127).int32]))
            else:
                mouseAdjusting = true
                # mouseKnob = i
        else:
            mouseAdjusting = false

        beginDrawing()
        if counter > 10:
            counter = 0
            clearBackground(RayWhite)

            fpsText = cstring($fmt"{getFPS()} fps")
            frameTimeText = cstring(fmt"{audioEngine.frameTime().float32/1000.0:.2f} 10e-6 s")
            drawText(fpsText, 10, screenHeight-22, 20, Red)
            drawText(frameTimeText, 10, screenHeight-44, 20, Red)

            synthParams = audioEngine.getInstrument().getInstrumentParamList()

            # drawText(fontPixantiqua, cstring($getFPS()), Vector2(x: 10.0 , y: 10.0),
            #          fontPixantiqua.baseSize.float32, 4.0, Red)
            let barSize = 200.int32
            let barMargin = 5.int32
            let startX = 50.int32
            let textX = 150.int32
            let startY = 10.int32

            for e, (k, v) in enumerate(synthParams.pairs):
                let locX = k.ord
                let row = startY + 22 * e.int32
                drawText(k.repr.cstring, startX, row, 20, Black)
                drawRectangle(startX + textX, row, barSize, 20, LightGray)
                let faderSize = (barSize - barMargin * 2)
                let encValue = (v.normalized() * 256.0).int32
                drawRectangle(startX + textX + barMargin, row + barMargin,
                    (faderSize * encValue) div 256, 20 - (barMargin*2), Red)

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
