type AudioContext = ref object
    sampleRate: float32
    sampleTime: float32

proc newAudioContext*(sampleRate: float32): AudioContext =
    result = AudioContext()
    result.sampleRate = sampleRate
    result.sampleTime = 1.0 / sampleRate
