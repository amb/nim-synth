import std/[sequtils, strutils, math, strformat, os, bitops, sets, tables, enumerate]
import ../rtmidi
import ../midi/[midievents, encoders]

var devOut = initMidiOut()

proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    if midiMsg.len > 0:
        # echo $midiMsg.makeMidiEvent()
        echo midiMsg
        devOut.sendMidi(midiMsg[..2])

proc main =
    var devIn = initMidiIn()
    if devIn.portCount() > 0:
        devIn.setCallback(midiInCallback)
        echo "MIDI in ports:"
        for i in 0..<devIn.portCount():
            echo "Port #", i, ": ", devIn.portName(i)
            if "mpk mini" in devIn.portName(i).toLower():
                devIn.openPort(i)
    else:
        echo "No MIDI input devices found"

    if devOut.portCount() > 0:
        echo "MIDI out ports:"
        for i in 0..<devOut.portCount():
            echo "Port #", i, ": ", devOut.portName(i)
            if "midifiddler" in devOut.portName(i).toLower():
                devOut.openPort(i)
    else:
        echo "No MIDI output devices found"

    while true:
        sleep(500)

main()
