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

proc `$`*(event: MidiEvent): string =
    result = "MidiEvent(kind: "
    case event.kind:
    of NoteOff: result.add("NoteOff")
    of NoteOn: result.add("NoteOn")
    of PitchBend: result.add("PitchBend")
    of Aftertouch: result.add("Aftertouch")
    of ControlChange: result.add("ControlChange")
    of ProgramChange: result.add("ProgramChange")
    of ChannelAftertouch: result.add("ChannelAftertouch")
    of SystemExclusive: result.add("SystemExclusive")
    of EndOfTrack: result.add("EndOfTrack")
    of Text: result.add("Text")
    of Copyright: result.add("Copyright")
    of TrackName: result.add("TrackName")
    of Tempo: result.add("Tempo")
    of SMPTEOffset: result.add("SMPTEOffset")
    of TimeSignature: result.add("TimeSignature")
    of KeySignature: result.add("KeySignature")
    of PrefixPort: result.add("PrefixPort")
    of MetaEvent: result.add("MetaEvent")
    of Undefined: result.add("Undefined")
    result.add(", channel: ")
    result.add($event.channel)
    result.add(", param: [")
    for i in 0..3:
        result.add($event.param[i])
        if i < 3:
            result.add(", ")
    result.add("])")

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
    result = MidiEvent()
    result.timeStamp = 0
    result.kind = midiEventType(data[0].uint8)
    assert result.kind != Undefined
    if hasChannel(result.kind):
        result.channel = data[0].uint8.and(0x0F)
    for i in 0..min(3, data.len-2):
        result.param[i] = data[i+1].uint8
