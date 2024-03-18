import std/[bitops, streams]

proc sw32(x: uint32): uint32 =
    return (x.bitand(0xff000000.uint32)) shr 24 + (x.bitand(0x00ff0000.uint32)) shr 8 +
           (x.bitand(0x0000ff00.uint32)) shl 8 + (x.bitand(0x000000ff.uint32)) shl 24

proc sw16(x: uint16): uint16 =
    return (x.bitand(0xff00.uint16)) shr 8 + (x.bitand(0x00ff.uint16)) shl 8

proc r32*(fs: FileStream): uint32 =
    return fs.readUint32().sw32()

proc r16*(fs: FileStream): uint16 =
    return fs.readUint16().sw16()

proc readVarLen*(fs: FileStream): uint32 =
    # Read variable length MIDI value
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

if isMainModule:
    echo "Running tests."
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
