type RingBuffer*[L: static[int], T] = object
    buffer: array[L, T]
    position: int32

proc write*[L, T](rb: var RingBuffer[L, T], sample: T) {.inline.} =
    rb.buffer[rb.position] = sample
    inc rb.position
    if rb.position >= rb.buffer.len:
        rb.position = 0

proc read*[L, T](rb: RingBuffer[L, T], rewind: uint32): T {.inline.} =
    var readPos = rb.position - rewind.int32
    while readPos < 0:
        readPos += rb.buffer.len.int32
    return rb.buffer[readPos]
