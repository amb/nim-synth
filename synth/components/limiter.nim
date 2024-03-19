import std/[math]

type Limiter* = object
    roof: float32
    limit: float32
    speed: float32

proc newLimiter*(roof: float32, speed: float32): Limiter =
    result.roof = roof
    result.limit = 1.0
    result.speed = speed

proc render*(limiter: var Limiter, input: float32): float32 =
    result = input * limiter.limit

    if result.abs > limiter.roof:
        let correction = limiter.roof / result.abs
        limiter.limit *= correction
        result *= correction

    if limiter.limit < 1.0:
        limiter.limit += limiter.speed
        limiter.limit = min(limiter.limit, 1.0)

proc renderStereo*(limiter: var Limiter, pair: (float32, float32)): (float32, float32) =
    return (limiter.render(pair[0]), limiter.render(pair[1]))
