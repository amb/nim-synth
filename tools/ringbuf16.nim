type RingBuffer16*[T] = object
    buffer: array[65536, T]
    position: uint16

proc write*[T](rb: var RingBuffer16[T], sample: T) {.inline.} =
    rb.buffer[rb.position] = sample
    inc rb.position

proc read*[T](rb: RingBuffer16[T], rewind: uint16): T {.inline.} =
    # var pos: uint16 = rb.position - rewind
    # if pos < 0:
    #     pos += rb.buffer.len
    # assert pos >= 0 and pos < rb.buffer.len
    return rb.buffer[uint16(rb.position - rewind)]
