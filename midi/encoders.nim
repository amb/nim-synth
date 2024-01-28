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

proc newEncoderInput*(value: float32, step: float32, minValue: float32, maxValue: float32): EncoderInput =
    result.step = step
    result.minValue = minValue
    result.maxValue = maxValue
    result.value = value
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

proc value*(enc: var EncoderInput): float32 = enc.value

proc updateRelative*(enc: var EncoderInput, midival: int) = 
    enc.value += enc.decode(midival)
    enc.clamp()
