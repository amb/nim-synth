# Nim conversion of the following work:

# Copyright 2012 Stefano D'Angelo <zanga.mail@gmail.com>

# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# This model is based on a reference implementation of an algorithm developed by
# Stefano D'Angelo and Vesa Valimaki, presented in a paper published at ICASSP in 2013.
# This improved model is based on a circuit analysis and compared against a reference
# Ngspice simulation. In the paper, it is noted that this particular model is
# more accurate in preserving the self-oscillating nature of the real filter.

# References: "An Improved Virtual Analog Model of the Moog Ladder Filter"
# Original Implementation: D'Angelo, Valimaki

import math, strformat

const
    MOOG_PI = 3.141592653589793
    VT = 0.312

type ImprovedMoog* = object
    V: array[0..3, float32]
    dV: array[0..3, float32]
    tV: array[0..3, float32]
    x: float32
    g: float32
    drive: float32
    resonance: float32
    cutoff: float32
    sampleRate: float32

proc setResonance*(im: var ImprovedMoog; r: float32) =
    im.resonance = r

proc setCutoff*(im: var ImprovedMoog; c: float32) =
    im.cutoff = c
    im.x = (MOOG_PI * im.cutoff) / im.sampleRate
    im.g = 4.0 * MOOG_PI * VT * im.cutoff * (1.0 - im.x) / (1.0 + im.x)
    echo fmt"im.g: {im.g}, im.x: {im.x}, {c}"

proc newImprovedMoog*(sampleRate: float32): ImprovedMoog =
    result = ImprovedMoog()
    result.drive = 1.0
    result.sampleRate = sampleRate
    result.setCutoff(1000.0)
    result.setResonance(0.1)

proc fast_tanh(x: float32): float32 =
    let x2 = x * x;
    return x * (27.0 + x2) / (27.0 + 9.0 * x2);

proc render*(im: var ImprovedMoog, sample: float32): float32 =
    let dV0 = -im.g * (tanh((im.drive * sample + im.resonance * im.V[3]) / (2.0 * VT)) + im.tV[0])
    im.V[0] += (dV0 + im.dV[0]) / (2.0 * im.sampleRate)
    im.dV[0] = dV0
    im.tV[0] = tanh(im.V[0] / (2.0 * VT))

    let dV1 = im.g * (im.tV[0] - im.tV[1])
    im.V[1] += (dV1 + im.dV[1]) / (2.0 * im.sampleRate)
    im.dV[1] = dV1
    im.tV[1] = tanh(im.V[1] / (2.0 * VT))

    let dV2 = im.g * (im.tV[1] - im.tV[2])
    im.V[2] += (dV2 + im.dV[2]) / (2.0 * im.sampleRate)
    im.dV[2] = dV2
    im.tV[2] = tanh(im.V[2] / (2.0 * VT))

    let dV3 = im.g * (im.tV[2] - im.tV[3])
    im.V[3] += (dV3 + im.dV[3]) / (2.0 * im.sampleRate)
    im.dV[3] = dV3
    im.tV[3] = tanh(im.V[3] / (2.0 * VT))

    return im.V[3]
