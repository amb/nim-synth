import std/[math, random]

type ADSR* = object
    attack*: float32
    decay*: float32
    sustain*: float32
    release*: float32
    finished*: bool
    released: bool
    previous: float32
    previousProgress: float32
    progress: float32

proc render*(adsr: var ADSR, step: float32): float32 =
    if adsr.finished:
        return 0.0

    if not adsr.released:
        # Attack envelope
        if adsr.progress < adsr.attack:
            result = adsr.progress / adsr.attack
            adsr.progress += step
        # Decay envelope
        elif adsr.progress < adsr.attack + adsr.decay:
            result = 1.0 - (adsr.progress - adsr.attack) / adsr.decay * (1.0 - adsr.sustain)
            adsr.progress += step
        # Sustain
        else:
            result = adsr.sustain

        adsr.previous = result
        adsr.previousProgress = adsr.progress

    # Release envelope
    else:
        result = adsr.previous - (adsr.progress - adsr.previousProgress) / adsr.release * adsr.previous
        adsr.progress += step

        # Finished
        if adsr.progress >= adsr.previousProgress + adsr.release:
            adsr.finished = true

proc release*(adsr: var ADSR) =
    adsr.released = true