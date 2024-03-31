import std/[strutils, os, sequtils]
import ../external/rtmidi
import cligen

var enableDebug = true
var running = true

proc handler() {.noconv.} =
    running = false
    echo "\nExiting..."

setControlCHook(handler)

var devOut = initMidiOut()
var devIn = initMidiIn()

var currentPatch: uint8 = 0
var patchUpTrigger: array[3, byte] = [0x00.byte, 0x00.byte, 0x00.byte]
var patchDownTrigger: array[3, byte] = [0x00.byte, 0x00.byte, 0x00.byte]

proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    if midiMsg.len > 0:
        var midiResult = newSeq[byte](3)
        midiResult[0] = midiMsg[0]
        midiResult[1] = midiMsg[1]
        midiResult[2] = midiMsg[2]

        # Hardcoded remappings for Akai MPK Mini Mk3 program and bank changes

        # if midiResult == @[0xC9.byte, 0x02.byte, 0x00.byte]:
        if midiResult == patchUpTrigger:
            # Map CC change to program change
            if currentPatch < 127:
                currentPatch += 1
            midiResult[0] = 0xC0
            midiResult[1] = currentPatch
            midiResult[2] = 0x00

        # if midiResult == @[0xC9.byte, 0x01.byte, 0x00.byte]:
        if midiResult == patchDownTrigger:
            # Map CC change to program change
            if currentPatch > 0:
                currentPatch -= 1
            midiResult[0] = 0xC0
            midiResult[1] = currentPatch
            midiResult[2] = 0x00

        if enableDebug:
            for i in 0..<midiResult.len:
                stdout.write(midiResult[i].toHex(2), " ")
            echo ""
        devOut.sendMidi(midiResult)

proc midipipe(source = ""; destination = ""; list = false; debug = true; patchUp = "C9 02 00";
        patchDown = "C9 01 00"): int =
    var openIn: int = 0
    var openOut: int = 0

    if (source.len == 0 or destination.len == 0) and not list:
        echo "Please provide both source and destination MIDI port names"
        return 0

    if devIn.portCount() > 0:
        devIn.setCallback(midiInCallback)
        echo "\nMIDI in ports:"
        for i in 0..<devIn.portCount():
            echo "Port #", i, ": ", devIn.portName(i)
            if source in devIn.portName(i).toLower() and not list:
                devIn.openPort(i)
                inc openIn
    else:
        echo "No MIDI input devices found"
        return 0

    if devOut.portCount() > 0:
        echo "\nMIDI out ports:"
        for i in 0..<devOut.portCount():
            echo "Port #", i, ": ", devOut.portName(i)
            if destination in devOut.portName(i).toLower() and not list:
                devOut.openPort(i)
                inc openOut
    else:
        echo "No MIDI output devices found"
        return 0

    if list:
        return 0

    if (openIn == 0 or openOut == 0):
        echo "\nNo MIDI devices found based on search strings"
        return 0

    # Init mapping
    let put = patchUp.split(" ")
    doAssert put.len == 3, "Invalid patch up trigger"
    for i in 0..<patchUpTrigger.len:
        patchUpTrigger[i] = put[i].parseHexInt().byte

    let pdt = patchDown.split(" ")
    doAssert pdt.len == 3, "Invalid patch down trigger"
    for i in 0..<patchDownTrigger.len:
        patchDownTrigger[i] = pdt[i].parseHexInt().byte

    echo patchUpTrigger
    echo patchDownTrigger

    enableDebug = debug
    stdout.write("\nMidi pipe running. Press Ctrl+C to exit.")
    stdout.flushFile()

    while running:
        sleep(50)

dispatch midipipe, help = {
    "source": "Source MIDI port name matching string (in lower case)",
    "destination": "Destination MIDI port name matching string (in lower case)",
    "list": "List available MIDI ports and exit",
    "debug": "Enable debug mode (--debug:false to disable)",
}

