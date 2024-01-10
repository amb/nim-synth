import std/[sequtils, strutils, strformat, streams, bitops]
import gm_defs
import readvar

type MidiEvent* = ref object
    timeStamp*: uint64
    eventType*: uint8
    channel*: uint8
    param1*: uint8
    param2*: uint8

type MidiTrack* = ref object
    name*: string
    events*: seq[MidiEvent]

type MidiFile* = ref object
    trackCount*: uint32
    timeDivision*: uint16
    tempo*: uint32
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
            var channel: uint8 = (if fb < 0x80: prevChannel else: fb.bitand(0x0f.byte))

            var midiEvt = MidiEvent(
                timeStamp: timeStamp, 
                eventType: eventType, 
                channel: channel, 
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
                        # TODO: possibility to change tempo in the middle of the song
                        # Tempo is microseconds per quarter note
                        var tempo: uint32 = metaBytes[0].uint32.shl(16) + metaBytes[1].uint32.shl(8) + metaBytes[2].uint32
                        # echo "Tempo: ", tempo
                        # echo "BPM: ", 60000000 div tempo
                        result.tempo = tempo
                    elif metaType == 0x03:
                        # TODO: track name is currently set only once
                        result.tracks[trackId].name = metaBytes
                    # elif metaType == 0x58:
                    #     echo "Time signature: ", metaBytes[0].uint8, " ", metaBytes[1].uint8, " ", metaBytes[2].uint8, " ", metaBytes[3].uint8
                    # elif metaType == 0x59:
                    #     echo "Key signature: ", metaBytes[0].uint8, " ", metaBytes[1].uint8
                    # else:
                    #     echo "Meta event: ", metaType.toHex, " length: ", metaLength, " bytes: ", metaBytes
                    
                    # assert deltaTime == 0

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
                prevChannel = channel
            else:
                # Program change and channel aftertouch events
                midiEvt.param1 = mfile.readUint8()
                result.tracks[trackId].events.add(midiEvt)

        assert mfile.getPosition() == startLoc + trackSize.int

if isMainModule:
    var midiData = loadMidiFile("ff4battle.mid")

    echo "tempo: ", midiData.tempo
    for track in midiData.tracks:
        echo track.name
        if track.events.len > 0:
            echo "  events: ", track.events.len
            echo track.events[^1].timeStamp

