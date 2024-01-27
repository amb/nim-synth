type AudioComponent = ref object
    sampleRate: float32
    sampleTime: float32
    runtime: uint64
    finished: bool

proc newAudioComponent*(sampleRate: float32): AudioComponent =
    result = AudioComponent()
    result.sampleRate = sampleRate
    result.sampleTime = 1.0 / sampleRate
    result.runtime = 0
    result.finished = false

proc reset*(self: AudioComponent) =
    self.runtime = 0
    self.finished = false

proc tick*(self: AudioComponent) =
    inc self.runtime

proc getSampleRate*(self: AudioComponent): float32 =
    return self.sampleRate

proc getRuntime*(self: AudioComponent): uint64 =
    return self.runtime

proc getSampleTime*(self: AudioComponent): float32 =
    return self.sampleTime

proc finish*(self: AudioComponent): bool =
    self.finished = true

proc isFinished*(self: AudioComponent): bool =
    return self.finished
