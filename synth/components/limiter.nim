import std/[math]

type TrackingEnvelope* = object
    lowValue*, highValue*: float32
    decaySpeed, attackSpeed: float32
    minEnvelope: float32

proc newTrackingEnvelope(a, s: float32): TrackingEnvelope =
    result = TrackingEnvelope()
    result.decaySpeed = s
    result.attackSpeed = a
    result.lowValue = 0.0
    result.highValue = 0.0
    result.minEnvelope = 0.1

proc track(tm: var TrackingEnvelope, input: float32) =
    if input > tm.highValue:
        tm.highValue += tm.attackSpeed
        if tm.highValue > input:
            tm.highValue = input

    if input < tm.lowValue:
        tm.lowValue -= tm.attackSpeed
        if tm.lowValue < input:
            tm.lowValue = input

    if tm.highValue - tm.lowValue > tm.minEnvelope:
        tm.highValue -= tm.decaySpeed
        tm.lowValue += tm.decaySpeed

type Limiter* = object
    limit: float32
    count: uint16
    tracker: TrackingEnvelope

proc newLimiter*(roof: float32, decaySpeed: float32): Limiter =
    result.limit = roof
    result.tracker = newTrackingEnvelope(0.05, decaySpeed)

proc render*(lim: var Limiter, input: float32): float32 =
    let limt2 = lim.limit * 2.0

    lim.tracker.track(input)

    let high = lim.tracker.highValue
    let low  = lim.tracker.lowValue
    let middle = (high + low) * 0.5

    # Limit input to the tracking envolpes and remove offset
    result = input
    if result > high:
        result = high
    if result < low:
        result = low
    result = result - middle

    # inc lim.count
    # if lim.count == 0:
    #     echo (high, low)

    if high-low >= limt2:
        # Limit to [-limit, limit]
        result = result * limt2 / (high-low)

proc renderStereo*(limiter: var Limiter, pair: (float32, float32)): (float32, float32) =
    return (limiter.render(pair[0]), limiter.render(pair[1]))
