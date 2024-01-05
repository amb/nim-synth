import raylib, std/[math, strformat, sets]

const
    screenWidth = 800
    screenHeight = 450

const
    MaxSamples = 512
    MaxSamplesPerUpdate = 4096

var
    frequency: float32 = 440
    sineIdx: float32 = 0

proc audioInputCallback(buffer: pointer; frames: uint32) {.cdecl.} =
    let incr = frequency / 44100'f32
    let d = cast[ptr UncheckedArray[int16]](buffer)
    for i in 0..<frames:
        d[i] = int16(32000'f32 * sin(2 * PI * sineIdx))
        sineIdx += incr
        if sineIdx > 1: sineIdx -= 1

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
        if isKeyDown(mkey):
            result.add(mk_id)

    for mk_id, mkey in musicKeys2:
        if isKeyDown(mkey):
            result.add(mk_id - 12)

proc main =
    # Initialization
    initWindow(screenWidth, screenHeight, "raylib [audio] example - raw audio streaming")
    defer: closeWindow()

    var fontPixantiqua = loadFont("res/pixantiqua.ttf")

    initAudioDevice()
    defer: closeAudioDevice()

    setAudioStreamBufferSizeDefault(MaxSamplesPerUpdate)

    var stream = loadAudioStream(48000, 16, 1)
    setAudioStreamCallback(stream, audioInputCallback)

    # Buffer for the single cycle waveform we are synthesizing
    var data = newSeq[int16](MaxSamples)

    playAudioStream(stream)

    setTargetFPS(30)
    while not windowShouldClose():
        var mousePosition = getMousePosition()
        if isMouseButtonDown(Left):
            let fp = mousePosition.y
            frequency = 40 + fp
            let pan = mousePosition.x/screenWidth
            setAudioStreamPan(stream, pan)

        for n in getActiveNotes():
            frequency = 440 * pow(2, (n-12).float32/12)

        if frequency < 0: frequency = 0

        beginDrawing()
        clearBackground(RayWhite)

        var textOut = (fmt"Frequency: {frequency.int32}").cstring
        drawText(fontPixantiqua, textOut, Vector2(x: 10.0 , y: 10.0), fontPixantiqua.baseSize.float32, 4.0, Red)

        # Draw the current buffer state proportionate to the screen
        for i in 0..<screenWidth:
            var position: Vector2
            position.x = float32(i)
            position.y = 100 + 50*data[i*MaxSamples div screenWidth].float32/32000
            drawPixel(position.x.int32, position.y.int32, Red)
            drawPixel(position.x.int32, position.y.int32 + 1, Red)
        endDrawing()

main()
