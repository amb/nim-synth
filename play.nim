import std/[sequtils, strutils, math, strformat, os, tables]
import midi/[midiread, midievents]
import raylib
import audioengine
import audiosynth
import cligen

proc main(fileName=""): int =
    startAudioEngine()
    defer: closeAudioEngine()

    echo "Loading: ", fileName
    var midiData = loadMidiFile(fileName)

    var trackLocations: seq[int]
    # echo "tempo: ", midiData.tempo
    for track_id, track in midiData.tracks:
        stdout.write(fmt"[{track_id}] {track.name} ")
        if track.events.len > 0:
            stdout.write(fmt"e:{track.events.len}, t:{track.events[^1].timeStamp}")
        echo ""
        trackLocations.add(0)

    var cursor: uint64 = 0
    var tempo: uint32 = 300000
    # var sleepMultiplier = 1
    while true:
        # Find lowest timestamp from tracks
        var pick = 0
        var minLoc: uint64 = uint64.high
        for i in 0..<trackLocations.len:
            # let i = 1
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

        # Calculate sleep time until next event
        if ev.kind == Tempo:
            tempo = readTempo(ev.param[0..2])
            echo "tempo change: ", tempo

        # tempo / division = duration of one tick in microseconds
        let sleepTime = ((ev.timeStamp - cursor).int64 * tempo.int64) div (midiData.timeDivision.int64 * 1000)
        if sleepTime > 0:
            # TODO: microsecond accuracy sleep
            sleep(sleepTime)
            cursor = ev.timeStamp

        audioengine.sendCommand(ev)

    sleep(500)
    return 0

dispatch main
