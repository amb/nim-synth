import std/[math, random]
import envelope

# Sustain is not an envelope, but a value
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

proc newADSR*(): ADSR =
    result = ADSR()
    result.finished = false
    result.released = false
    result.currentEnvelope = PART_ATTACK.ord
    setEnvelopeSequence(cast[ptr UncheckedArray[Envelope]](result.envelopes[0].addr), 3, defaultTimes, defaultValues)
    echo result.envelopes

proc setAttack*(adsr: var ADSR, value: float32) =
    adsr.envelopes[PART_ATTACK.ord].totalTime = value

proc setDecay*(adsr: var ADSR, value: float32) =
    adsr.envelopes[PART_DECAY.ord].totalTime = value

proc setSustain*(adsr: var ADSR, value: float32) =
    adsr.envelopes[PART_DECAY.ord].endValue = value

proc setRelease*(adsr: var ADSR, value: float32) =
    adsr.envelopes[PART_RELEASE.ord].totalTime = value

proc render*(adsr: var ADSR, step: float32): float32 =
    # echo "Render"
    if adsr.finished:
        echo "isfin"
        return 0.0

    if not adsr.released:
        # echo "noadsr"
        var current = adsr.envelopes[adsr.currentEnvelope]
        if current.isFinished() and adsr.currentEnvelope == PART_ATTACK.ord:
            echo "Attack finished!"
            adsr.currentEnvelope = PART_DECAY.ord
            current = adsr.envelopes[adsr.currentEnvelope]
        result = current.render(step)
        # Save the current value of the envelope AD phase to smoothly transition to the release phase
        adsr.storedOutput = result
    else:
        # echo "is adsr"
        var current = adsr.envelopes[PART_RELEASE.ord]
        result = current.render(step)
        if current.isFinished():
            echo "Finished!"
            adsr.finished = true

proc release*(adsr: var ADSR) =
    echo "Releasing!"
    adsr.envelopes[PART_RELEASE.ord].startValue = adsr.storedOutput
    adsr.released = true

proc reset*(adsr: var ADSR) =
    adsr.finished = false
    adsr.released = false
    adsr.currentEnvelope = PART_ATTACK.ord
    adsr.storedOutput = 0.0
    for i in 0..2:
        adsr.envelopes[i].reset()

proc isFinished*(adsr: var ADSR): bool =
    return adsr.finished
