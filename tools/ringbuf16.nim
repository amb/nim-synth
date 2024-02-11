type RingBuffer16* = object
    buffer: array[65536, int16]
    position: uint16

proc write*(rb: var RingBuffer16, sample: int16) =
    rb.buffer[rb.position] = sample
    inc rb.position

proc read*(rb: RingBuffer16, rewind: int): int16 =
    var pos: int = rb.position.int - rewind
    if pos < 0:
        pos += rb.buffer.len
    assert pos >= 0 and pos < rb.buffer.len
    return rb.buffer[pos]
