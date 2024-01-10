import std/[sequtils, strutils, strformat, streams, bitops]
import gm_defs

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

assert readVarLen(@[0x00]) == 0x00
assert readVarLen(@[0x40]) == 0x40
assert readVarLen(@[0x7F]) == 0x7F
assert readVarLen(@[0x81, 0x00]) == 0x80
assert readVarLen(@[0xC0, 0x00]) == 0x2000
assert readVarLen(@[0xFF, 0x7F]) == 0x3FFF
assert readVarLen(@[0x81, 0x80, 0x00]) == 0x4000
assert readVarLen(@[0xC0, 0x80, 0x00]) == 0x100000
assert readVarLen(@[0xFF, 0xFF, 0x7F]) == 0x1FFFFF
assert readVarLen(@[0x81, 0x80, 0x80, 0x00]) == 0x200000
assert readVarLen(@[0xC0, 0x80, 0x80, 0x00]) == 0x8000000
assert readVarLen(@[0xFF, 0xFF, 0xFF, 0x7F]) == 0xFFFFFFF

type MidiEvent* = ref object
    timeStamp*: uint64
    eventType*: uint8
    midiChannel*: uint8
    param1*: uint8
    param2*: uint8

type MidiTrack* = ref object
    name*: string
    events*: seq[MidiEvent]

type MidiFile* = ref object
    trackCount*: uint32
    timeDivision*: uint16
    tracks*: seq[MidiTrack]

proc loadMidiHeader(fs: FileStream): MidiFile =
    # MIDI header chunk
    doAssert fs.readStr(4) == "MThd"
    doAssert fs.r32() == 6
    doAssert fs.r16() == 1

    var trackCount: uint32 = fs.r16().uint32
    let timeDivision = fs.r16()

    return MidiFile(
        trackCount: trackCount,
        timeDivision: timeDivision,
        tracks: @[]
    )

proc loadMidiFile*(fname: string): MidiFile =
    let mfile = newFileStream(fname)        

    result = loadMidiHeader(mfile)

    # Track chunks
    for trackId in 0..<result.trackCount:
        doAssert mfile.readStr(4) == "MTrk"
        result.tracks.add(MidiTrack(name: "", events: @[]))
        var trackSize = mfile.r32()
        # echo fmt"Track [{trackId}] size: {trackSize}"
        let startLoc = mfile.getPosition()
        var prevEvent, prevChannel: uint8
        var timeStamp: uint64 = 0
        while mfile.getPosition() < startLoc + trackSize.int:
            let deltaTime = mfile.readVarLen()
            timeStamp += deltaTime

            let fb = mfile.readUint8()

            # If fb < 0x80 it means that the event has a running status, and reads previous event type and channel
            var eventType: uint8 = (if fb < 0x80: prevEvent else: fb.bitand(0xf0.byte) shr 4)
            var midiChannel: uint8 = (if fb < 0x80: prevChannel else: fb.bitand(0x0f.byte))

            var midiEvt = MidiEvent(
                timeStamp: timeStamp, 
                eventType: eventType, 
                midiChannel: midiChannel, 
            )

            if eventType == 0xF:
                # Meta event
                if fb == 0xFF:
                    let metaType = mfile.readUint8()
                    let metaLength = mfile.readVarLen()
                    let metaBytes = mfile.readStr(metaLength.int)
                    if metaType == 0x2F:
                        # End of track
                        discard
                    elif metaType == 0x51:
                        echo "Tempo: ", metaBytes[0].uint8, " ", metaBytes[1].uint8, " ", metaBytes[2].uint8
                    elif metaType == 0x58:
                        echo "Time signature: ", metaBytes[0].uint8, " ", metaBytes[1].uint8, " ", metaBytes[2].uint8, " ", metaBytes[3].uint8
                    elif metaType == 0x59:
                        echo "Key signature: ", metaBytes[0].uint8, " ", metaBytes[1].uint8
                    elif metaType == 0x03:
                        result.tracks[trackId].name = metaBytes
                        # echo "Name: ", metaBytes
                    else:
                        echo "Meta event: ", metaType.toHex, " length: ", metaLength, " bytes: ", metaBytes
                    doAssert deltaTime == 0

                # Sysex event
                elif fb == 0xF0:
                    let sysexLength = mfile.readVarLen()
                    let sysexBytes = mfile.readStr(sysexLength.int)
                    echo "Sysex event: ", sysexLength, " bytes: ", sysexBytes
                elif fb == 0xF7:
                    let sysexLength = mfile.readVarLen()
                    let sysexBytes = mfile.readStr(sysexLength.int)
                    echo "Sysex event: ", sysexLength, " bytes: ", sysexBytes
                else:
                    echo "Unknown event: ", fb.toHex

            elif eventType != 0xC and eventType != 0xD:
                # Note on, note off, polyphonic aftertouch, controller change and pitch bend events
                midiEvt.param1 = (if fb <= 0x80: fb else: mfile.readUint8())
                midiEvt.param2 = mfile.readUint8()
                result.tracks[trackId].events.add(midiEvt)

                prevEvent = eventType
                prevChannel = midiChannel
            else:
                # Program change and channel aftertouch events
                midiEvt.param1 = mfile.readUint8()
                result.tracks[trackId].events.add(midiEvt)

        assert mfile.getPosition() == startLoc + trackSize.int

discard loadMidiFile("shovel.mid")
