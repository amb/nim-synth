import std/[math, tables, sequtils, strformat, sets]
import ../midi/encoders
import audiosynth
import voicestatic

type Instrument* = ref object
    machine*: VoiceStatic
    ccMapping: Table[int, string]

proc newInstrument*(): Instrument =
    result = Instrument()
    result.machine = newVoiceStatic()

proc setMapping*(instrument: var Instrument, control: int, param: string) =
    instrument.ccMapping[control] = param
    echo "Set mapping: ", control, " -> ", param

proc getInstrumentParamList*(instrument: Instrument): Table[string, EncoderInput] =
    return instrument.machine.reference.getParamList()

proc controlMessage*(instrument: var Instrument, control: int, value: int) =
    # TODO: not exactly according to the MIDI spec
    if control in instrument.ccMapping:
        # instrument.reference.nudgeParam(mapping[control], value)
        instrument.machine.reference.setParam(instrument.ccMapping[control], value.float32 / 127.0)
    elif control == 0x00:
        # bank select
        echo "Unhandled: bank select"
    elif control == 0x01:
        # modulation
        echo "Unhandled: modulation"
    elif control == 0x05:
        # TODO: finish
        # portamento time
        echo "Unhandled: portamento time"
    elif control == 0x06:
        # data entry (MSB)
        echo "Unhandled: data entry (MSB)"
    elif control == 0x07:
        # volume
        # TODO: volume param
        # instrument.machine.volume = max(0, value).float32 / 127.0
        discard
    elif control == 0x0A:
        # pan
        echo "Unhandled: pan"
    elif control == 0x0B:
        # expression
        echo "Unhandled: expression"
    elif control == 0x41:
        # portamento
        echo "Unhandled: portamento"
    else:
        echo "Unhandled control event: ", control, " ", value
