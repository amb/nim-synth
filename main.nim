import raylib, std/[sequtils, math, strformat, sets, locks, os]
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

proc main =
    initWindow(screenWidth, screenHeight, "raylib [audio] example - raw audio streaming")
    defer: closeWindow()

    startAudioEngine()
    defer: closeAudioEngine()

    var fontPixantiqua = loadFont("res/pixantiqua.ttf")

    # TODO: proper quick keyboard polling

    # setTargetFPS(60)
    while not windowShouldClose():
        var mousePosition = getMousePosition()
        if isMouseButtonDown(Left):
            discard
            # let fp = mousePosition.y
            # frequency = 40 + fp
            # let pan = mousePosition.x/screenWidth
            # setAudioStreamPan(stream, pan)

        # echo synthCounts()

        beginDrawing()
        clearBackground(RayWhite)

        drawText(fontPixantiqua, $getFPS(), Vector2(x: 10.0 , y: 10.0), fontPixantiqua.baseSize.float32, 4.0, Red)

        # Draw the current buffer state proportionate to the screen
        # for i in 0..<screenWidth:
        #     let x: int32 = i.int32
        #     let y: int32 = 100 + 50*data[i*audioengine.MaxSamples div screenWidth] div 32000
        #     drawPixel(x, y, Red)
        #     drawPixel(x, y + 1, Red)
        endDrawing()

        assert getFrameTime() > 0.0

        for n in getReleasedNotes():
            channelMessage(n, ControlMessage.Release)
        
        for n in getPressedNotes():
            addSynth(n, newAudioSynth(440.0 * pow(2, (n+12).float32/12)))
        
        sleep(2)

main()
