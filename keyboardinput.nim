import midi/[midievents]
import raylib

const musicKeys1 = [
    KeyboardKey.Q, KeyboardKey.Two, KeyboardKey.W, KeyboardKey.Three, KeyboardKey.E, KeyboardKey.R,
    KeyboardKey.Five, KeyboardKey.T, KeyboardKey.Six, KeyboardKey.Y, KeyboardKey.Seven, KeyboardKey.U,
    KeyboardKey.I, KeyboardKey.Nine, KeyboardKey.O, KeyboardKey.Zero, KeyboardKey.P
]

const musicKeys2 = [
    KeyboardKey.Z, KeyboardKey.S, KeyboardKey.X, KeyboardKey.D, KeyboardKey.C, KeyboardKey.V,
    KeyboardKey.G, KeyboardKey.B, KeyboardKey.H, KeyboardKey.N, KeyboardKey.J, KeyboardKey.M,
    KeyboardKey.Comma, KeyboardKey.L, KeyboardKey.Period
]

proc getPressedNotes(): seq[int] =
    for mk_id, mkey in musicKeys1:
        if isKeyPressed(mkey):
            result.add(mk_id + 12)

    for mk_id, mkey in musicKeys2:
        if isKeyPressed(mkey):
            result.add(mk_id)

proc getReleasedNotes(): seq[int] =
    for mk_id, mkey in musicKeys1:
        if isKeyReleased(mkey):
            result.add(mk_id + 12)

    for mk_id, mkey in musicKeys2:
        if isKeyReleased(mkey):
            result.add(mk_id)

proc readKeys*(): seq[MidiEvent] =
    # Interpret keyboard as keyboard
    for n in getReleasedNotes():
        result.add([0x80, (n+36), 0, 0].makeMidiEvent())

    for n in getPressedNotes():
        result.add([0x90, (n+36), 127, 0].makeMidiEvent())
