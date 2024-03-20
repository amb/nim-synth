import std/[math, random]
import envelope

# Sustain is not an envelope, but a value
const defaultValues = [0.0, 1.0, 0.0]
const defaultTimes = [0.01, 0.1, 0.1]

type ADSR_parts = enum
    PART_ATTACK = 0,
    PART_DECAY = 1,
    PART_RELEASE = 2

type ADSR* = object
    finished*: bool
    released: bool
    storedOutput: float32
    currentEnvelope: int
    envelopes: array[4, Envelope]

proc newADSR*(): ADSR =
    result = ADSR()
    result.finished = false
    result.released = false
    result.currentEnvelope = 0
    setEnvelopeSequence(cast[ptr UncheckedArray[Envelope]](result.envelopes[0].addr), 4, defaultValues, defaultTimes)

proc setAttack*(adsr: var ADSR, value: float32) =
    adsr.envelopes[0].totalTime = value

proc setDecay*(adsr: var ADSR, value: float32) =
    adsr.envelopes[1].totalTime = value

proc setSustain*(adsr: var ADSR, value: float32) =
    adsr.envelopes[1].endValue = value

proc setRelease*(adsr: var ADSR, value: float32) =
    adsr.envelopes[2].totalTime = value

proc render*(adsr: var ADSR, step: float32): float32 =
    if adsr.finished:
        return 0.0

    if not adsr.released:
        var current = adsr.envelopes[adsr.currentEnvelope]
        if current.isFinished() and adsr.currentEnvelope == PART_ATTACK.ord:
            adsr.currentEnvelope = PART_DECAY.ord
            current = adsr.envelopes[adsr.currentEnvelope]
        result = current.render(step)
        # Save the current value of the envelope AD phase to smoothly transition to the release phase
        adsr.storedOutput = result
    else:
        var current = adsr.envelopes[PART_RELEASE.ord]
        result = current.render(step)
        if current.isFinished():
            adsr.finished = true

proc release*(adsr: var ADSR) =
    adsr.envelopes[PART_RELEASE.ord].startValue = adsr.storedOutput
    adsr.released = true

proc reset*(adsr: var ADSR) =
    adsr.finished = false
    adsr.released = false
    adsr.currentEnvelope = 0
    adsr.storedOutput = 0.0
    for i in 0..3:
        adsr.envelopes[i].reset()
