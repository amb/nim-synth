import std/[sequtils, strutils, math, strformat, os, tables]
import raylib
import audioengine
import audiosynth
import midi/midiread

proc main =
    startAudioEngine()
    defer: closeAudioEngine()

    var midiData = loadMidiFile("midi/ff4golbez.mid")

    var trackLocations: seq[int]
    echo "tempo: ", midiData.tempo
    for track_id, track in midiData.tracks:
        stdout.write(fmt"[{track_id}] {track.name} ")
        if track.events.len > 0:
            stdout.write(fmt"e:{track.events.len}, t:{track.events[^1].timeStamp}")
        echo ""
        trackLocations.add(0)

    var cursor: uint64 = 0
    while true:
        # Find lowest timestamp from tracks
        var pick = 0
        var minLoc: uint64 = uint64.high
        for i in 0..<trackLocations.len:
            # let i = 4
            if trackLocations[i] < midiData.tracks[i].events.len:
                let evt = midiData.tracks[i].events[trackLocations[i]]
                let trackLoc = evt.timeStamp
                if trackLoc < minLoc:
                    pick = i
                    minLoc = trackLoc

        # No more events in any track
        if minLoc == uint64.high:
            break

        # Play picked event
        let ev = midiData.tracks[pick].events[trackLocations[pick]]
        inc trackLocations[pick]

        sleep((ev.timeStamp - cursor).int * 2)
        cursor = ev.timeStamp
        audioengine.sendCommand(ev)

    sleep(500)

main()
