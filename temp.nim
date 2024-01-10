import std/[sequtils, strutils, math, strformat, os]
import raylib
import audioengine
import audiosynth
import midi/midiread

proc main =
    startAudioEngine()
    defer: closeAudioEngine()

    var midiData = loadMidiFile("midi/ff4battle.mid")

    echo "tempo: ", midiData.tempo
    for track_id, track in midiData.tracks:
        echo fmt"[{track_id}] {track.name}"
        if track.events.len > 0:
            echo "  events: ", track.events.len
            echo track.events[^1].timeStamp

    var cursor: uint64 = 0
    for ev in midiData.tracks[1].events:
        sleep((ev.timeStamp - cursor).int * 2)
        cursor = ev.timeStamp
        let fb = ev.eventType shl 4 + ev.channel
        audioengine.sendCommand([fb.byte, ev.param1.byte, ev.param2.byte, 0x0.byte])
        echo fmt"[{ev.timeStamp}] {ev.eventType} {ev.channel} {ev.param1} {ev.param2}"

    sleep(500)

main()
