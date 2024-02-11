import std/[math, tables, sequtils, strformat, sets]
import ../midi/encoders
import audiosynth
import voicedynamic

type Instrument* = ref object
    machine*: VoiceDynamic
    ccMapping: Table[int, SynthParamKind]

proc newInstrument*(): Instrument =
    result = Instrument()
    result.machine = newVoiceDynamic()

proc setMapping*(instrument: var Instrument, control: int, param: SynthParamKind) =
    instrument.ccMapping[control] = param
    echo "Set mapping: ", control, " -> ", param

proc getInstrumentParamList*(instrument: Instrument): array[SynthParamKind, EncoderInput] =
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
        instrument.machine.volume = max(0, value).float32 / 127.0
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
