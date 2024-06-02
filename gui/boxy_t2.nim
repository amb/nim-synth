import boxy, opengl, windy, os

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
makeContextCurrent(window)

loadExtensions()

let bxy = newBoxy()

var mousePos: Vec2

let
    typeface1 = readTypeface("../res/fontb.ttf")
    font1 = newFont(typeface1)

font1.size = 20
font1.paint = "#FFFFFF"

let poem = """
Once upon a midnight dreary, while I pondered, weak and weary,
Over many a quaint and curious volume of forgotten lore—
    While I nodded, nearly napping, suddenly there came a tapping,
As of some one gently rapping, rapping at my chamber door.
“’Tis some visitor,” I muttered, “tapping at my chamber door—
    Only this and nothing more.”
"""

proc drawText(
    bxy: Boxy,
    imageKey: string,
    transform: Mat3,
    typeface: Typeface,
    text: string,
    size: float32,
    color: Color
) =
    var font = newFont(typeface)
    font.size = size
    font.paint = color
    let
        arrangement = typeset(@[newSpan(text, font)], bounds = vec2(1280, 800))
        globalBounds = arrangement.computeBounds(transform).snapToPixels()
        textImage = newImage(globalBounds.w.int, globalBounds.h.int)
        imageSpace = translate(-globalBounds.xy) * transform
    textImage.fillText(arrangement, imageSpace)

    bxy.addImage(imageKey, textImage)
    bxy.drawImage(imageKey, globalBounds.xy)

let
    arrangement = typeset(@[newSpan(poem, font1)], bounds = vec2(1280, 800))
    snappedBounds = arrangement.computeBounds().snapToPixels()
    textImage = newImage(snappedBounds.w.int, snappedBounds.h.int)

textImage.fillText(arrangement, translate(-snappedBounds.xy))

bxy.addImage("text", textImage)

# Called when it is time to draw a new frame.
window.onFrame = proc() =
    bxy.beginFrame(window.size)
    bxy.drawImage("text", snappedBounds.xy + mousePos)
    bxy.endFrame()

    # Swap buffers displaying the new Boxy frame.
    window.swapBuffers()

window.onMouseMove = proc() =
    mousePos = vec2(window.mousePos)

window.onButtonPress = proc(button: Button) =
    echo "onButtonPress ", button
    echo "down: ", window.buttonDown[button]
    echo "pressed: ", window.buttonPressed[button]
    echo "released: ", window.buttonReleased[button]
    echo "toggle: ", window.buttonToggle[button]
    if button == KeyEscape:
        window.closeRequested = true

while not window.closeRequested:
    if window.minimized or not window.visible:
        sleep(10)
    pollEvents()
