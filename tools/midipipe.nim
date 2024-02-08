import std/[sequtils, strutils, math, strformat, os, bitops, sets, tables, enumerate]
import ../rtmidi
import ../midi/[midievents, encoders]

proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    if midiMsg.len > 0:
        echo $midiMsg.makeMidiEvent()

proc main =
    var devIn = initMidiIn()
    if devIn.portCount() > 0:
        devIn.openPort(1)
        devIn.setCallback(midiInCallback)
    echo "MIDI ports:"
    for i in 0..<devIn.portCount():
        echo "Port #", i, ": ", devIn.portName(i)

    while true:
        sleep(50)

main()
