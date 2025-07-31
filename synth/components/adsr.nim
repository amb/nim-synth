import std/[math, random]
import envelope

# Sustain is not an envelope, but a value (last value of the decay envelope)
const defaultValues = [1.0, 0.5, 0.0]
const defaultTimes = [0.01, 0.1, 0.5]

type ADSR_parts = enum
    PART_ATTACK = 0,
    PART_DECAY = 1,
    PART_RELEASE = 2

type ADSR* = object
    finished: bool
    released: bool
    storedOutput: float32
    currentEnvelope: int
    envelopes: array[3, Envelope]

proc initADSR*(adsr: var ADSR) =
    adsr.finished = false
    adsr.released = false
    adsr.currentEnvelope = PART_ATTACK.ord
    var previousValue = 0.0
    for i in 0..2:
        adsr.envelopes[i].initEnvelope(previousValue, defaultValues[i], defaultTimes[i])
        previousValue = defaultValues[i]

proc newADSR*(): ADSR =
    result = ADSR()
    initADSR(result)

proc setAttack*(adsr: var ADSR, value: float32) =
    adsr.envelopes[PART_ATTACK.ord].totalTime = value

proc setDecay*(adsr: var ADSR, value: float32) =
    adsr.envelopes[PART_DECAY.ord].totalTime = value

proc setSustain*(adsr: var ADSR, value: float32) =
    adsr.envelopes[PART_DECAY.ord].endValue = value

proc setRelease*(adsr: var ADSR, value: float32) =
    adsr.envelopes[PART_RELEASE.ord].totalTime = value

proc render*(adsr: var ADSR, step: float32): float32 =
    if adsr.finished:
        return 0.0

    if not adsr.released:
        if adsr.currentEnvelope == PART_ATTACK.ord and adsr.envelopes[adsr.currentEnvelope].isFinished():
            adsr.currentEnvelope = PART_DECAY.ord
        result = adsr.envelopes[adsr.currentEnvelope].render(step)
        # Save the current value of the envelope AD phase to smoothly transition to the release phase
        adsr.storedOutput = result
    else:
        result = adsr.envelopes[PART_RELEASE.ord].render(step)
        if adsr.envelopes[PART_RELEASE.ord].isFinished():
            adsr.finished = true

proc release*(adsr: var ADSR) =
    adsr.envelopes[PART_RELEASE.ord].startValue = adsr.storedOutput
    adsr.released = true

proc reset*(adsr: var ADSR) =
    adsr.finished = false
    adsr.released = false
    adsr.currentEnvelope = PART_ATTACK.ord
    adsr.storedOutput = 0.0
    for i in 0..2:
        adsr.envelopes[i].reset()

proc isFinished*(adsr: var ADSR): bool {.inline.} =
    return adsr.finished
