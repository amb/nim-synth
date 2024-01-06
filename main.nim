import raylib, std/[sequtils, math, strformat, sets]
import audioengine
import audiosynth

const
    screenWidth = 800
    screenHeight = 450

proc getActiveNotes(): seq[int] =
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

    for mk_id, mkey in musicKeys1:
        if isKeyPressed(mkey):
            result.add(mk_id)

    for mk_id, mkey in musicKeys2:
        if isKeyPressed(mkey):
            result.add(mk_id - 12)

proc main =
    initWindow(screenWidth, screenHeight, "raylib [audio] example - raw audio streaming")
    defer: closeWindow()

    startAudioEngine()
    defer: closeAudioEngine()

    var fontPixantiqua = loadFont("res/pixantiqua.ttf")

    setTargetFPS(30)
    while not windowShouldClose():
        var mousePosition = getMousePosition()
        if isMouseButtonDown(Left):
            discard
            # let fp = mousePosition.y
            # frequency = 40 + fp
            # let pan = mousePosition.x/screenWidth
            # setAudioStreamPan(stream, pan)

        for n in getActiveNotes():
            addSynth(newAudioSynth(440.0 * pow(2, (n+24).float32/12)))

        echo synthCounts()

        beginDrawing()
        clearBackground(RayWhite)

        # var textOut = (fmt"Frequency: {frequency.int32}").cstring
        var textOut = "foo"
        drawText(fontPixantiqua, textOut, Vector2(x: 10.0 , y: 10.0), fontPixantiqua.baseSize.float32, 4.0, Red)

        # Draw the current buffer state proportionate to the screen
        # for i in 0..<screenWidth:
        #     let x: int32 = i.int32
        #     let y: int32 = 100 + 50*data[i*audioengine.MaxSamples div screenWidth] div 32000
        #     drawPixel(x, y, Red)
        #     drawPixel(x, y + 1, Red)
        endDrawing()

main()
