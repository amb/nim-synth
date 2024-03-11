import std/[math]

type Resonant* = object
    cutoff: float32
    resonance: float32
    position: float32
    previousPosition: float32

proc newResonant*(cutoff, resonance: float32): Resonant =
    result.cutoff = cutoff
    result.resonance = resonance
    result.position = 0.0
    result.previousPosition = 0.0

proc render*(res: var Resonant, input: float32): float32 =
    # Verlet integration
    let velocity = res.position - res.previousPosition
    let force = (input - res.position) * res.cutoff
    res.previousPosition = res.position
    res.position += velocity * res.resonance + force
    return res.position

proc setCutoff*(res: var Resonant, cutoff: float32) =
    # res.cutoff = cutoff / sampleRate
    res.cutoff = cutoff * cutoff

proc setResonance*(res: var Resonant, resonance: float32) =
    res.resonance = resonance
