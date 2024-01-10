import std/[sequtils, strutils, strformat, streams, bitops]
import gm_defs
import readvar

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
