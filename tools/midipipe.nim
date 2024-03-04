import std/[strutils, os]
import ../external/rtmidi
import cligen
# import ../midi/[midievents, encoders]

var enableDebug = true

var devOut = initMidiOut()

proc midiInCallback(timestamp: float64; midiMsg: openArray[byte]) {.thread.} =
    if midiMsg.len > 0:
        # echo $midiMsg.makeMidiEvent()
        if enableDebug:
            echo midiMsg
        devOut.sendMidi(midiMsg[0..2])

proc midipipe(source = "", destination = "", list = false, debug = true): int =
    var openIn: int = 0
    var openOut: int = 0

    if (source.len == 0 or destination.len == 0) and not list:
        echo "Please provide both source and destination MIDI port names"
        return 0

    var devIn = initMidiIn()
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

    enableDebug = debug

    while true:
        sleep(500)

dispatch midipipe, help = {
    "source": "Source MIDI port name matching string (in lower case)",
    "destination": "Destination MIDI port name matching string (in lower case)",
    "list": "List available MIDI ports and exit",
    "debug": "Enable debug mode (--debug:false to disable)",
}

