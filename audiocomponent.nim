type AudioComponent* = object
    sampleRate: float32
    sampleTime: float32
    runtime: uint64
    finished: bool

proc sampleRate*(self: AudioComponent): float32 = self.sampleRate
proc sampleTime*(self: AudioComponent): float32 = self.sampleTime
proc runtime*(self: AudioComponent): uint64 = self.runtime

proc newAudioComponent*(sampleRate: float32): AudioComponent =
    AudioComponent(sampleRate: sampleRate, sampleTime: 1.0 / sampleRate, runtime: 0, finished: false)

proc reset*(self: var AudioComponent) =
    self.runtime = 0
    self.finished = false

proc tick*(self: var AudioComponent) =
    inc self.runtime

proc finish*(self: var AudioComponent) =
    self.finished = true

proc isFinished*(self: AudioComponent): bool =
    return self.finished
