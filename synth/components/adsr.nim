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

proc curve*(val, curve: float32): float32 {.inline.} =
    ## Positive curve = log-like, negative curve = exp-like
    return 1 - (1 - val) * (1 - val * curve)

proc render*(adsr: var ADSR, step: float32): float32 =
    if adsr.finished:
        return 0.0

    if not adsr.released:
        # Attack envelope
        if adsr.progress < adsr.attack:
            # result = (adsr.progress / adsr.attack).curve(1.0)
            result = (adsr.progress / adsr.attack)
            adsr.progress += step
        # Decay envelope
        elif adsr.progress < adsr.attack + adsr.decay:
            let pg = ((adsr.progress - adsr.attack) / adsr.decay).curve(-1.0)
            result = 1.0 - pg * (1.0 - adsr.sustain)
            adsr.progress += step
        # Sustain
        else:
            result = adsr.sustain

        adsr.previous = result
        adsr.previousProgress = adsr.progress

    # Release envelope
    else:
        let pg = ((adsr.progress - adsr.previousProgress) / adsr.release).curve(-1.0)
        result = adsr.previous - pg * adsr.previous
        adsr.progress += step

        # Finished
        if adsr.progress >= adsr.previousProgress + adsr.release:
            adsr.finished = true

proc release*(adsr: var ADSR) =
    adsr.released = true

proc reset*(adsr: var ADSR) =
    adsr.finished = false
    adsr.released = false
    adsr.progress = 0.0
    adsr.previous = 0.0
    adsr.previousProgress = 0.0
