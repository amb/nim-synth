type Envelope* = object
    startValue*, endValue*: float32
    time*, totalTime*: float32
    curve*: float32

proc curve(val, curve: float32): float32 {.inline.} =
    ## Positive curve = log-like, negative curve = exp-like
    return 1 - (1 - val) * (1 - val * curve)

proc replace*(e: var Envelope, startValue, endValue, totalTime: float32)  =
    e.startValue = startValue
    e.endValue = endValue
    e.totalTime = totalTime
    e.time = 0.0
    e.curve = 0.0

proc newEnvelope*(startValue, endValue, totalTime: float32): Envelope =
    result = Envelope()
    result.replace(startValue, endValue, totalTime)

proc buildEnvelopeSequence*(times, values: var openArray[float32]): seq[Envelope] =
    var previousValue = 0.0
    for i in 0..<times.len:
        result.add(newEnvelope(previousValue, values[i], times[i]))
        previousValue = values[i]

# proc setEnvelopeSequence*(e: var openArray[Envelope], times, values: var openArray[float32]) =
#     var previousValue = 0.0
#     assert e.len == times.len
#     assert e.len == values.len
#     for i in 0..<times.len:
#         e[i].replace(previousValue, values[i], times[i])
#         previousValue = values[i]

proc setEnvelopeSequence*(e: ptr UncheckedArray[Envelope], alen: int, times, values: openArray[float]) =
    var previousValue = 0.0
    assert alen == times.len
    assert alen == values.len
    for i in 0..<times.len:
        e[i].replace(previousValue, values[i], times[i])
        previousValue = values[i]

proc render*(e: var Envelope, step: float32): float32 =
    if e.time < e.totalTime:
        result = e.startValue + (e.endValue - e.startValue) * (e.time / e.totalTime)
        # result = curve(result, e.curve)
        e.time += step
    else:
        result = e.endValue

proc isFinished*(e: Envelope): bool =
    result = e.time >= e.totalTime

proc reset*(e: var Envelope) =
    e.time = 0.0
