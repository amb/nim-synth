import std/[strutils, os]
import ../external/rtmidi
# import ../midi/[midievents, encoders]

var devOut = initMidiOut()

proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    if midiMsg.len > 0:
        # echo $midiMsg.makeMidiEvent()
        echo midiMsg
        devOut.sendMidi(midiMsg[0..2])

proc main =
    var openIn: int = 0
    var openOut: int = 0
    var portSource = "mpk mini"
    var portDest = "midifiddler"

    var devIn = initMidiIn()
    if devIn.portCount() > 0:
        devIn.setCallback(midiInCallback)
        echo "\nMIDI in ports:"
        for i in 0..<devIn.portCount():
            echo "Port #", i, ": ", devIn.portName(i)
            if portSource in devIn.portName(i).toLower():
                devIn.openPort(i)
                inc openIn
    else:
        echo "No MIDI input devices found"
        return

    if devOut.portCount() > 0:
        echo "\nMIDI out ports:"
        for i in 0..<devOut.portCount():
            echo "Port #", i, ": ", devOut.portName(i)
            if portDest in devOut.portName(i).toLower():
                devOut.openPort(i)
                inc openOut
    else:
        echo "No MIDI output devices found"
        return

    if openIn == 0 or openOut == 0:
        echo "\nNo MIDI devices found based on search strings"
        return

    while true:
        sleep(500)

main()
