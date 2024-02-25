import std/math

type EncoderInput* = object
    value: float32
    step: float32
    minValue: float32
    maxValue: float32

proc decode*(enc: var EncoderInput, midival: int): float32 {.inline.} =
    if midival < 64:
        return enc.step * float32(midival)
    elif midival > 65:
        return -enc.step * float32(128-midival)

proc clamp*(enc: var EncoderInput) {.inline.} =
    if enc.value > enc.maxValue:
        enc.value = enc.maxValue
    elif enc.value < enc.minValue:
        enc.value = enc.minValue
    if enc.step == 1.0:
        enc.value = enc.value.round()

proc newEncoderInput*(value: float32, step: float32, minValue: float32, maxValue: float32): EncoderInput =
    result.value = value
    result.step = step
    result.minValue = minValue
    result.maxValue = maxValue
    result.clamp()

proc inc*(enc: var EncoderInput) =
    enc.value += enc.step
    if enc.value > enc.maxValue:
        enc.value = enc.maxValue

proc dec*(enc: var EncoderInput) =
    enc.value -= enc.step
    if enc.value < enc.minValue:
        enc.value = enc.minValue

proc `+=`*(enc: var EncoderInput, value: int) =
    enc.value += value.float32 * enc.step
    enc.clamp()

proc `-=`*(enc: var EncoderInput, value: int) =
    enc.value -= value.float32 * enc.step
    enc.clamp()

proc set*(enc: var EncoderInput, value: float32) =
    enc.value = value
    enc.clamp()

proc value*(enc: EncoderInput): float32 {.inline.} = enc.value

proc normalized*(enc: EncoderInput): float32 {.inline.} =
    ## Returned value is between 0 and 1
    return (enc.value - enc.minValue) / (enc.maxValue - enc.minValue)

proc denormalized*(enc: EncoderInput, value: float32): float32 {.inline.} =
    ## Convert a normalized value (between 0 and 1) to normal range
    return value * (enc.maxValue - enc.minValue) + enc.minValue

proc curve*(enc: EncoderInput, curve: float32): float32 {.inline.} =
    ## Positive curve = log-like, negative curve = exp-like
    let l = enc.maxValue - enc.minValue
    let t = (enc.value - enc.minValue) / l
    return (1 - (1 - t) * (1 - t * curve)) * l + enc.minValue

proc updateRelative*(enc: var EncoderInput, midival: int) {.inline.} = 
    enc.value += enc.decode(midival)
    enc.clamp()

proc updateAbsolute*(enc: var EncoderInput, value: int) {.inline.} = 
    enc.value = enc.denormalized(value.float32 / 127.0)
    enc.clamp()

proc updateMiddle*(enc: var EncoderInput, value: float32) {.inline.} = 
    enc.value = (enc.maxValue + enc.minValue) * 0.5 + value * enc.step
    enc.clamp()
