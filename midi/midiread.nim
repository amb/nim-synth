import std/[sequtils, strutils, strformat, streams, bitops, os]
import gm_defs
import readvar
import midievents

type MidiTrack* = ref object
    name*: string
    events*: seq[MidiEvent]

type MidiFile* = ref object
    trackCount*: uint32
    timeDivision*: uint16
    tracks*: seq[MidiTrack]

proc loadMidiHeader(fs: FileStream): MidiFile =
    # MIDI header chunk
    let headerTag = fs.readStr(4)
    if headerTag == "RIFF":
        # Skip RIFF header
        echo "MIDI is in RIFF format"
        # RIFF RMID chunk size
        discard fs.readUInt32()
        # 'RMID'
        assert fs.readStr(4) == "RMID"
        # 'data'
        assert fs.readStr(4) == "data"
        # MIDI chunk size
        discard fs.readUInt32()
        # 'MThd'
        assert fs.readStr(4) == "MThd"
    else:
        assert headerTag == "MThd", fmt"Invalid header tag: {headerTag}"
    assert fs.r32() == 6
    assert fs.r16() == 1

    var trackCount: uint32 = fs.r16().uint32
    let timeDivision = fs.r16()

    return MidiFile(
        trackCount: trackCount,
        timeDivision: timeDivision,
        tracks: @[]
    )

proc loadMidiFile*(fname: string): MidiFile =
    if fileExists(fname) == false:
        echo "File not found: ", fname
        return MidiFile()

    let mfile = newFileStream(fname)

    result = loadMidiHeader(mfile)

    # Track chunks
    for trackId in 0..<result.trackCount:
        assert mfile.readStr(4) == "MTrk"
        result.tracks.add(MidiTrack(name: "", events: @[]))

        let trackSize = mfile.r32()
        let startLoc = mfile.getPosition()

        var prevByte: uint8
        var timeStamp: uint64 = 0
        while mfile.getPosition() < startLoc + trackSize.int:
            let deltaTime = mfile.readVarLen()
            timeStamp += deltaTime

            let nextByte = mfile.readUint8()

            # If nextByte < 0x80 it means that the event has a running status
            var fb: uint8
            if nextByte < 0x80:
                fb = prevByte
            else:
                prevByte = nextByte
                fb = nextByte

            let evt = midiEventType(fb)
            var midiEvt = MidiEvent(timeStamp: timeStamp, channel: fb.bitand(0x0f.byte), kind: evt)

            if evt == MetaEvent:
                let metaType = mfile.readUint8()
                let metaLength = mfile.readVarLen()
                let metaBytes = mfile.readStr(metaLength.int)

                let metaEvent = metaEventType(metaType)
                midiEvt.kind = metaEvent

                if metaEvent == TrackName:
                    result.tracks[trackId].name = metaBytes

                if metaEvent == Tempo:
                    for i in 0..<3:
                        midiEvt.param[i] = metaBytes[i].uint8
                    result.tracks[trackId].events.add(midiEvt)

            elif evt.hasChannel():
                # Use running status if available
                midiEvt.param[0] = (if nextByte < 0x80: nextByte else: mfile.readUint8())
                midiEvt.param[1] = mfile.readUint8()
                result.tracks[trackId].events.add(midiEvt)

            elif evt == ProgramChange or evt == ChannelAftertouch:
                midiEvt.param[0] = mfile.readUint8()
                result.tracks[trackId].events.add(midiEvt)

            else:
                assert false, fmt"Unhandled event type {evt}"

        assert mfile.getPosition() == startLoc + trackSize.int

if isMainModule:
    var midiData = loadMidiFile("midi/shovel.mid")

    # echo "tempo: ", midiData.tempo
    for track in midiData.tracks:
        if track.events.len > 0:
            echo "Track: ", track.name, ", events: ", track.events.len, ", last: ", track.events[^1].timeStamp
        else:
            echo "Text: ", track.name
