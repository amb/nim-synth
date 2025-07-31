import std/math
import allpass, combfilter

const rCombTuning = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
const rAllPassTuning = [556, 441, 341, 225]

const stereoSpread = 23
const fixedGain = 0.015'f32
const scaleWet = 3
const scaleDry = 2
const scaleDamp = 0.4'f32
const scaleRoom = 0.28'f32
const offsetRoom = 0.7'f32

const NUM_ALLPASS = 4
const NUM_COMB = 8

type ReverbChannel = object
    combf: array[NUM_COMB, CombFilter[2048]]
    allp: array[NUM_ALLPASS, AllPass[1024]]

type Reverb* = object
    left, right: ReverbChannel
    roomsize, damp, wet, dry, width, mode: float32
    wet1, wet2, gain, roomsize1, damp1: float32

proc newReverbChannel(delay: uint16): ReverbChannel =
    result = ReverbChannel()

    for i in 0..<NUM_ALLPASS:
        result.allp[i].delay = rAllPassTuning[i].uint16 + delay

    for i in 0..<NUM_COMB:
        result.combf[i].delay = rCombTuning[i].uint16 + delay

proc update(self: var Reverb) =
    self.wet1 = self.wet * (self.width / 2'f32 + 0.5f)
    self.wet2 = self.wet * ((1'f32 - self.width) / 2'f32)

    self.roomsize1 = self.roomsize
    self.damp1 = self.damp
    self.gain = fixedGain

    for i in 0..<NUM_COMB:
        self.left.combf[i].feedBack = self.roomsize1
        self.right.combf[i].feedBack = self.roomsize1

    for i in 0..<NUM_COMB:
        self.left.combf[i].damping = self.damp1
        self.right.combf[i].damping = self.damp1

proc setRoomSize(self: var Reverb, value: float32) =
    self.roomsize = (value * scaleRoom) + offsetRoom
    self.update()

proc getRoomSize(self: Reverb): float32 =
    (self.roomsize - offsetRoom) / scaleRoom

proc setDamp(self: var Reverb, value: float32) =
    self.damp = value * scaleDamp
    self.update()

proc getDamp(self: Reverb): float32 =
    self.damp / scaleDamp

proc setWet(self: var Reverb, value: float32) =
    self.wet = value * scaleWet
    self.update()

proc getWet(self: Reverb): float32 =
    self.wet / scaleWet

proc setDry(self: var Reverb, value: float32) =
    self.dry = value * scaleDry

proc getDry(self: Reverb): float32 =
    self.dry / scaleDry

proc setWidth(self: var Reverb, value: float32) =
    self.width = value
    self.update()

proc getWidth(self: Reverb): float32 =
    self.width

proc newReverb*(): Reverb =
    var reverb = Reverb()
    reverb.left = newReverbChannel(0)
    reverb.right = newReverbChannel(stereoSpread)

    reverb.roomsize = 0.5'f32
    reverb.damp = 0.5'f32
    reverb.wet = 1'f32/scaleWet
    reverb.dry = 0
    reverb.width = 1

    reverb.setRoomSize(0.9)
    reverb.setDamp(0.99)

    return reverb

proc renderStereo*(self: var Reverb, input: float32): (float32, float32) =
    var outL, outR: float32

    # Comb filters in parallel
    for i in 0..<NUM_COMB:
        outL += self.left.combf[i].render(input)
        outR += self.right.combf[i].render(input)

    # Allpass filters in series
    for i in 0..<NUM_ALLPASS:
        outL = self.left.allp[i].render(outL)
        outR = self.right.allp[i].render(outR)

    # Mix output
    let lc = outL * self.wet1 + outR * self.wet2 + input * self.dry
    let rc = outR * self.wet1 + outL * self.wet2 + input * self.dry

    return (input * self.gain + lc, input * self.gain + rc)
