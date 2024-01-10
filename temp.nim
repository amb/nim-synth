import std/[sequtils, strutils, math, strformat, os, tables]
import raylib
import audioengine
import audiosynth
import midi/midiread

proc main =
    startAudioEngine()
    defer: closeAudioEngine()

    var midiData = loadMidiFile("midi/ff4battle.mid")

    var trackLocations: seq[int]
    echo "tempo: ", midiData.tempo
    for track_id, track in midiData.tracks:
        echo fmt"[{track_id}] {track.name}"
        if track.events.len > 0:
            echo "  events: ", track.events.len
            echo track.events[^1].timeStamp
        trackLocations.add(0)

    var cursor: uint64 = 0
    while true:
        # Find lowest timestamp from tracks

        # Min from tracks[*].events[trackLocations[*]].timeStamp
        var pick = 0
        var minLoc: uint64 = uint64.high
        for i in 0..<trackLocations.len:
            if trackLocations[i] >= midiData.tracks[i].events.len:
                continue

            let trackLoc = midiData.tracks[i].events[trackLocations[i]].timeStamp
            if trackLoc < minLoc:
                pick = i
                minLoc = trackLoc

        if midiData.tracks[pick].events.len == trackLocations[pick]:
            break

        let ev = midiData.tracks[pick].events[trackLocations[pick]]
        inc trackLocations[pick]

        # Play event
        sleep((ev.timeStamp - cursor).int * 3)
        cursor = ev.timeStamp
        let fb = ev.eventType shl 4 + ev.channel
        audioengine.sendCommand([fb.byte, ev.param1.byte, ev.param2.byte, 0x0.byte])
        # echo fmt"[{ev.timeStamp}] {ev.eventType} {ev.channel} {ev.param1} {ev.param2}"
        # if ev.eventType == 0xC:
        #     echo "chan: ", ev.channel
        #     echo "pgm change: ", ev.param1

    sleep(500)

main()