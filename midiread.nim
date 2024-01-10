import std/[sequtils, strutils, strformat, streams, bitops]
import bight

proc sw32(x: uint32): uint32 =
    return (x.bitand(0xff000000.uint32)) shr 24 + (x.bitand(0x00ff0000.uint32)) shr 8 +
           (x.bitand(0x0000ff00.uint32)) shl 8 + (x.bitand(0x000000ff.uint32)) shl 24

proc sw16(x: uint16): uint16 =
    return (x.bitand(0xff00.uint16)) shr 8 + (x.bitand(0x00ff.uint16)) shl 8

proc r32(fs: FileStream): uint32 =
    return fs.readUint32().sw32()

proc r16(fs: FileStream): uint16 =
    return fs.readUint16().sw16()

proc readVarLen(fs: FileStream): uint32 =
    for _ in 0..3:
        let c = fs.readUint8().uint8
        result = (result shl 7).bitor(c.bitand(0x7F))
        if c.bitand(0x80) == 0:
            break

proc readVarLen(s: seq[int]): uint32 =
    for i in 0..<s.len:
        let c = s[i].uint8
        result = (result shl 7).bitor(c.bitand(0x7F))
        if c.bitand(0x80) == 0:
            break

doAssert readVarLen(@[0x00]) == 0x00
doAssert readVarLen(@[0x40]) == 0x40
doAssert readVarLen(@[0x7F]) == 0x7F
doAssert readVarLen(@[0x81, 0x00]) == 0x80
doAssert readVarLen(@[0xC0, 0x00]) == 0x2000
doAssert readVarLen(@[0xFF, 0x7F]) == 0x3FFF
doAssert readVarLen(@[0x81, 0x80, 0x00]) == 0x4000
doAssert readVarLen(@[0xC0, 0x80, 0x00]) == 0x100000
doAssert readVarLen(@[0xFF, 0xFF, 0x7F]) == 0x1FFFFF
doAssert readVarLen(@[0x81, 0x80, 0x80, 0x00]) == 0x200000
doAssert readVarLen(@[0xC0, 0x80, 0x80, 0x00]) == 0x8000000
doAssert readVarLen(@[0xFF, 0xFF, 0xFF, 0x7F]) == 0xFFFFFFF

let mfile = newFileStream("shovel.mid")

# MIDI header chunk

# MThd
doAssert mfile.readStr(4) == "MThd"

# 6 (chunk size)
echo mfile.r32()
# format type
echo mfile.r16()
# number of tracks
var trackCount: uint32 = mfile.r16().uint32
echo "tracks: ", trackCount
# time division
echo "division: ", mfile.r16()

# Track chunks
for trackId in 0..<trackCount:
    if mfile.readStr(4) != "MTrk":
        echo "Bad track header"
        break
    var trackSize = mfile.r32()
    echo fmt"Track [{trackId}],  size: {trackSize}"
    let startLoc = mfile.getPosition()
    var prevEvent, prevChannel: uint8
    var running: bool
    while mfile.getPosition() < startLoc + trackSize.int:
        let timeStamp = mfile.readVarLen()
        # echo "delta: ", timeStamp

        let fb = mfile.readUint8()
        
        var eventType: uint8
        var midiChannel: uint8

        # Running event
        if fb < 0x80:
            eventType = prevEvent
            midiChannel = prevChannel
            if not running:
                echo "running..."
            running = true
        else:
            eventType = fb.bitand(0xf0.byte) shr 4
            midiChannel = fb.bitand(0x0f.byte)
            running = false

        if eventType == 0xF:
            # Meta event
            if fb == 0xFF:
                let metaType = mfile.readUint8()
                let metaLength = mfile.readVarLen()
                let metaBytes = mfile.readStr(metaLength.int)
                if metaType == 0x2F:
                    echo "end of track"
                elif metaType == 0x51:
                    echo "tempo: ", metaBytes[0].uint8, " ", metaBytes[1].uint8, " ", metaBytes[2].uint8
                elif metaType == 0x58:
                    echo "time signature: ", metaBytes[0].uint8, " ", metaBytes[1].uint8, " ", metaBytes[2].uint8, " ", metaBytes[3].uint8
                elif metaType == 0x59:
                    echo "key signature: ", metaBytes[0].uint8, " ", metaBytes[1].uint8
                elif metaType == 0x03:
                    echo "name: ", metaBytes
                else:
                    echo "meta event: ", metaType.toHex, " length: ", metaLength, " bytes: ", metaBytes
                doAssert timeStamp == 0
            # Sysex event
            elif fb == 0xF0:
                let sysexLength = mfile.readVarLen()
                let sysexBytes = mfile.readStr(sysexLength.int)
                echo "sysex event: ", sysexLength, " bytes: ", sysexBytes
            elif fb == 0xF7:
                let sysexLength = mfile.readVarLen()
                let sysexBytes = mfile.readStr(sysexLength.int)
                echo "sysex event: ", sysexLength, " bytes: ", sysexBytes
            else:
                echo "Unknown event: ", fb.toHex
        elif eventType != 0xC and eventType != 0xD:
            let param1 = (if running: fb else: mfile.readUint8())
            let param2 = mfile.readUint8()

            if not running:
                echo fb.toHex, " ", param1.toHex, " ", param2.toHex

            prevEvent = eventType
            prevChannel = midiChannel

            # if eventType == 0x8:
            #     echo "note off: ", param1.toHex, " ", param2.toHex
            # elif eventType == 0x9:
            #     echo "note on: ", param1.toHex, " ", param2.toHex
            # elif eventType == 0xA:
            #     echo "polyphonic aftertouch: ", param1.toHex, " ", param2.toHex
            # elif eventType == 0xB:
            #     echo "controller change: ", param1.toHex, " ", param2.toHex
            # elif eventType == 0xE:
            #     echo "pitch bend: ", param1.toHex, " ", param2.toHex
            # else:
        else:
            let param1 = mfile.readUint8()
            fb.toHex, " ", param1.toHex
            # echo "evt: ", eventType.toHex, " channel: ", midiChannel.toHex, " 1: ", param1.toHex

        # echo "event type: ", eventType, " channel: ", midiChannel

    assert mfile.getPosition() == startLoc + trackSize.int

    echo ""

