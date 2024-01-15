type MidiEventType* = enum
    NoteOff,
    NoteOn,
    PitchBend,
    Aftertouch,
    ControlChange,
    ProgramChange,
    ChannelAftertouch,
    SystemExclusive,
    EndOfTrack,
    Text,
    Copyright,
    TrackName,
    Tempo,
    SMPTEOffset,
    TimeSignature,
    KeySignature,
    PrefixPort,
    MetaEvent,
    Undefined,

type MidiEvent* = ref object
    timeStamp*: uint64
    kind*: MidiEventType
    channel*: uint8
    param*: array[4, uint8]

proc readTempo*(data: openArray[byte]): uint32 = data[0].uint32.shl(16) + data[1].uint32.shl(8) + data[2].uint32

proc metaEventType*(fb: uint8): MidiEventType =
    result = case fb:
    of 0x01: Text
    of 0x02: Copyright
    of 0x03: TrackName
    of 0x21: PrefixPort
    of 0x2F: EndOfTrack
    of 0x51: Tempo
    of 0x54: SMPTEOffset
    of 0x58: TimeSignature
    of 0x59: KeySignature
    else: Undefined

proc midiEventType*(fb: uint8): MidiEventType =
    let eventType = fb.shr(4)
    if eventType == 0xF:
        return case fb:
        of 0xF0, 0xF7: SystemExclusive
        of 0xFF: MetaEvent
        else: Undefined
    elif eventType >= 0x8 and eventType <= 0xE:
        return case eventType:
        of 0x8: NoteOff
        of 0x9: NoteOn
        of 0xA: Aftertouch
        of 0xB: ControlChange
        of 0xC: ProgramChange
        of 0xD: ChannelAftertouch
        of 0xE: PitchBend
        else: Undefined
    else:
        return Undefined

proc isMetaEvent*(eventType: MidiEventType): bool =
    (eventType == EndOfTrack or
        eventType == Text or
        eventType == Copyright or
        eventType == TrackName or
        eventType == Tempo or
        eventType == SMPTEOffset or
        eventType == TimeSignature or
        eventType == KeySignature or
        eventType == PrefixPort or
        eventType == MetaEvent)

proc hasChannel*(eventType: MidiEventType): bool =
    (eventType == NoteOff or
        eventType == NoteOn or
        eventType == Aftertouch or
        eventType == ControlChange or
        eventType == PitchBend)

proc makeMidiEvent*[T](data: openArray[T]): MidiEvent =
    assert data.len == 4
    result = MidiEvent()
    result.timeStamp = 0
    result.kind = midiEventType(data[0].uint8)
    if hasChannel(result.kind):
        result.channel = data[0].uint8.and(0x0F)
    result.param[0] = data[1].uint8
    result.param[1] = data[2].uint8
    result.param[2] = data[3].uint8
