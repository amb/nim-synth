# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Date: Monday, March 11th 2024, 4:33:42 pm
# Copyright: Tommi Hyppänen

import std/[sequtils, strutils, math, strformat, os, bitops, sets, tables, enumerate, monotimes]
import raylib, raymath
import external/rtmidi
import midi/[midievents, encoders]
import synth/[instrument, audioengine]
import keyboardinput
# import gui

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

    # var fontPixantiqua = loadFont("res/pixantiqua.ttf")
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

    var synthParams: OrderedTable[string, EncoderInput] = audioEngine.getInstrument().getInstrumentParamList()
    var synthKeys: seq[string] = synthParams.keys.toSeq()

    let ccOffset = 24

    for e, (k, v) in enumerate(synthParams.pairs):
        # TODO: generate from actual config
        audioEngine.setMapping(e + ccOffset, k)

    var mouseAdjusting = false

    let barSize = 200.int32
    let barMargin = 5.int32
    let startX = 50.int32
    let textX = 150.int32
    let startY = 40.int32
    let rowSize = 22.int32

    var paramSelect = -1.int32
    var lastAdjustment = 0.int64

    while not windowShouldClose():
        # click/drag to adjust
        var mousePosition = getMousePosition()
        if isMouseButtonDown(Left):
            if mouseAdjusting:
                let current_tick = monotimes.getMonoTime().ticks()
                if current_tick - lastAdjustment > 20_000_000:
                    lastAdjustment = current_tick
                    let barLoc = mousePosition.x.int32 - startX - textX - barMargin
                    # if barLoc > 0 and barLoc < barSize - barMargin * 2:
                    var value = barLoc.float32 / (barSize - barMargin * 2).float32
                    if value < 0.0:
                        value = 0.0
                    if value > 1.0:
                        value = 1.0
                    if paramSelect >= 0 and paramSelect < synthParams.len:
                        audioEngine.sendCommand(makeMidiEvent([0xB0, ccOffset + paramSelect, (value * 127).int32]))
            else:
                mouseAdjusting = true
                echo "Mouse down at ", mousePosition
                let row = (mousePosition.y.int32 - startY + rowSize) div rowSize
                if row > 0 and row <= synthParams.len:
                    let pidx = row - 1
                    echo "Param ", synthKeys[pidx]
                    let barLoc = mousePosition.x.int32 - startX - textX - barMargin
                    if barLoc > 0 and barLoc < barSize - barMargin * 2:
                        let value = barLoc.float32 / (barSize - barMargin * 2).float32
                        echo "Location ", barLoc
                        echo "Value ", value
                        paramSelect = pidx
                        audioEngine.sendCommand(makeMidiEvent([0xB0, ccOffset + pidx, (value * 127).int32]))
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

            for e, (k, v) in enumerate(synthParams.pairs):
                let row = startY + rowSize * e.int32
                drawText(synthKeys[e].cstring, startX, row, 20, Black)
                drawRectangle(startX + textX, row, barSize, 20, LightGray)
                let faderSize = (barSize - barMargin * 2)
                let encValue = (v.normalized() * 256.0).int32
                drawRectangle(startX + textX + barMargin, row + barMargin,
                    (faderSize * encValue) div 256, (rowSize-2) - (barMargin*2), Red)

            # Draw the current buffer state proportionate to the screen
            for i in 0..<screenWidth:
                let x: int32 = i.int32
                let y: int32 = screenHeight - 55 + 50 * readBackBuffer(i).int32 div 32000
                drawPixel(x, y, Red)
                drawPixel(x, y + 1, Red)
        endDrawing()

        for msg in readKeys():
            audioengine.sendCommand(msg)

        if isKeyPressed(KeyboardKey.Enter):
            echo audioEngine.getInstrument().getInstrumentParamList()

        sleep(2)

        inc counter

main()
