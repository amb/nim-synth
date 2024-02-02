import std/[sequtils, strutils, math, strformat, os, bitops, sets, tables, enumerate]
import raylib, raymath
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

proc drawKnob(vl: Vector2, value: float32, txt: (string, string)) =
    let x = vl.x
    let y = vl.y
    drawRing(vl, 14.0, 20.0, 0.0, clamp(value * 360.0, 10.0, 360.0), 16, Black)
    # let l1 = Vector2(x: x + 19.0, y: y)
    # let l2 = Vector2(x: x + 19.0, y: y - 24.0 - up)
    # let l3 = Vector2(x: x - 19.0, y: y - 24.0 - up)
    # drawLine(l1, l2, 2.0, Black)
    # drawLine(l2, l3, 2.0, Black)
    let bigness: int32 = 20
    let b2 = bigness div 2
    drawText(($int(value*99)).cstring, x.int32-b2-1, y.int32-b2+1, bigness, Black)
    drawText(txt[0].cstring, x.int32-16, y.int32-44, b2, Black)
    drawText(txt[1].cstring, x.int32-16, y.int32-44-b2, b2, Black)
    # drawText(txt, x.int32-16, y.int32-44-up.int32, 20, Black)

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
    var knobNames: seq[(string, string)]
    var knobPositions: seq[Vector2]

    for e, (k, v) in enumerate(synthParams.pairs):
        # The knob name is the string including and after the second capitalized letter
        # TODO: generate from actual config
        var s = k.repr
        for i in 1..s.len:
            if s[i].isUpperAscii:
                let r = s[i..^1]
                let cat = s[0..i-1]
                knobNames.add((r, cat))
                knobPositions.add(Vector2(
                    x: float32(50 + (e.floorMod(14)) * 50),
                    y: float32(180 + (e div 14) * 120)))
                echo r
                break

    var mouseAdjusting = false
    var mouseKnob: int = -1
    while not windowShouldClose():
        # Knob adjustment with mouse, locks in after mousepress to have a more stable feel
        var mousePosition = getMousePosition()
        if isMouseButtonDown(Left):
            if mouseAdjusting:
                let i = mouseKnob
                let pos = knobPositions[i]
                let angle = math.arctan2(-(mousePosition.y - pos.y), -(mousePosition.x - pos.x))
                let value = (angle + PI) / (2 * PI)
                audioEngine.sendCommand(makeMidiEvent([0xB0, 24 + i.int32, (value * 127).int32]))
                echo fmt"{SynthParamKind(i).repr}: {value:.3f}"
            else:
                for k, v in synthParams.pairs:
                    let i = k.ord
                    let pos = knobPositions[i]
                    let dist = mousePosition.distance(pos)
                    if dist < 20:
                        mouseAdjusting = true
                        mouseKnob = i
                        break
        else:
            mouseAdjusting = false
            
        beginDrawing()
        if counter > 10:
            counter = 0
            clearBackground(RayWhite)

            fpsText = cstring($fmt"{getFPS()} fps")
            frameTimeText = cstring(fmt"{audioEngine.frameTime().float32/1000.0:.2f} 10e-6 s")
            synthParams = audioEngine.getInstrument().getInstrumentParamList()

            # drawText(fontPixantiqua, cstring($getFPS()), Vector2(x: 10.0 , y: 10.0), fontPixantiqua.baseSize.float32, 4.0, Red)
            drawText(fpsText, 10, 10, 32, Red)
            drawText(frameTimeText, 10, 40, 32, Red)

            for k, v in synthParams.pairs:
                let locX = k.ord
                drawKnob(knobPositions[locX], v.normalized(), knobNames[locX])

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
