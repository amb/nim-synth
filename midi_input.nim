import std/[monotimes, strformat, strutils, os]
import rtmidi


proc midiInCallback(timestamp: float64; msg: openArray[byte]) {.thread.} =
    stdout.write fmt"{timestamp:9.7f}: "
    for b in msg:
        stdout.write toHex(b)
        stdout.write ' '

    let messageText = case msg[0]:
        of 0x90: "Note On"
        of 0x80: "Note Off"
        of 0xB0: "Control Change"
        of 0xC0: "Program Change"
        of 0xE0: "Pitch Bend"
        else: "Unknown"

    stdout.write "  ", messageText
    echo ""

var devIn = initMidiIn()
echo devIn.portCount(), " MIDI input ports available."
for i in 0..<devIn.portCount():
    echo "  Input Port #", i, ": ", devIn.portName(i)
devIn.openPort(1)
devIn.setCallback(midiInCallback)
# defer: devIn.removeCallback()

var msg: seq[byte]

var startTime = getMonoTime()
# while startTime.ticks + 5_000_000_000 > getMonoTime().ticks:
while true:
    # var msgIn = devIn.recvMidi(msg)
    # if msg.len > 0:
    #     echo msgIn, " ", msg
    sleep(5)
    msg.setLen(0)
