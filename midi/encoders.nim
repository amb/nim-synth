type EncoderInput* = object
    value*: float32
    step*: float32
    minValue*: float32
    maxValue*: float32

proc update*(enc: var EncoderInput, midival: int) =
    if midival < 64:
        enc.value += enc.step * float32(midival)
        if enc.value > enc.maxValue:
            enc.value = enc.maxValue
    elif midival > 65:
        enc.value -= enc.step * float32(128-midival)
        if enc.value < enc.minValue:
            enc.value = enc.minValue
