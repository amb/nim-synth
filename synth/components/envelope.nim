type Envelope* = object
    startValue*, endValue*: float32
    time*, totalTime*: float32
    curve*: float32

proc curve(val, curve: float32): float32 {.inline.} =
    ## Positive curve = log-like, negative curve = exp-like
    return 1 - (1 - val) * (1 - val * curve)

proc initEnvelope*(e: var Envelope, startValue, endValue, totalTime: float32)  =
    e.startValue = startValue
    e.endValue = endValue
    e.totalTime = totalTime
    if e.totalTime <= 0.0:
        e.totalTime = 0.00001
    e.time = 0.0
    e.curve = 0.0

proc buildEnvelopeSequence*(times, values: var openArray[float32]): seq[Envelope] =
    var previousValue = 0.0
    for i in 0..<times.len:
        var envelope = Envelope()
        envelope.initEnvelope(previousValue, values[i], times[i])
        result.add(envelope)
        previousValue = values[i]

proc render*(e: var Envelope, step: float32): float32 =
    if e.time < e.totalTime:
        result = e.startValue + (e.endValue - e.startValue) * (e.time / e.totalTime)
        # result = curve(result, e.curve)
        e.time += step
    else:
        result = e.endValue

proc isFinished*(e: Envelope): bool {.inline.} =
    result = e.time >= e.totalTime

proc reset*(e: var Envelope) {.inline.} =
    e.time = 0.0
