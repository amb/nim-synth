# Moog filter
# https://www.musicdsp.org/en/latest/Filters/24-moog-vcf.html

import math

type MoogVCF* = object
    baseCutoff*: float32
    cutoff: float32
    fs: float32
    res: float32
    f: float32
    k: float32
    p: float32
    scale: float32
    r: float32
    y4: float32
    y1: float32
    y2: float32
    y3: float32
    oldx: float32
    oldy1: float32
    oldy2: float32
    oldy3: float32

proc initMoogVCF*(m: var MoogVCF, cutoff: float32, fs: float32, res: float32) =
    let coff = cutoff * 16.0
    m.cutoff = coff
    m.fs = fs
    m.res = res
    m.f = 2 * coff / fs
    # alt tuning: k=2*sin(f*pi/2)-1
    m.k = 3.6 * m.f - 1.6 * m.f * m.f - 1
    m.p = (m.k + 1) * 0.5
    m.scale = math.exp((1 - m.p) * 1.386249)
    m.r = m.res * m.scale

proc setCutoff*(m: var MoogVCF, cutoff: float32) =
    let coff = cutoff * 16.0
    m.cutoff = coff
    m.f = 2 * coff / m.fs
    m.k = 3.6 * m.f - 1.6 * m.f * m.f - 1
    m.p = (m.k + 1) * 0.5
    m.scale = math.exp((1 - m.p) * 1.386249)
    m.r = m.res * m.scale

proc setResonance*(m: var MoogVCF, res: float32) =
    m.res = res
    m.r = m.res * m.scale

proc processMoogVCF*(m: var MoogVCF, input: float32): float32 =
    var x = input - m.r * m.y4
    m.y1 = x * m.p + m.oldx * m.p - m.k * m.y1
    m.y2 = m.y1 * m.p + m.oldy1 * m.p - m.k * m.y2
    m.y3 = m.y2 * m.p + m.oldy2 * m.p - m.k * m.y3
    m.y4 = m.y3 * m.p + m.oldy3 * m.p - m.k * m.y4
    m.y4 = m.y4 - (m.y4 * m.y4 * m.y4) / 6
    m.oldx = x
    m.oldy1 = m.y1
    m.oldy2 = m.y2
    m.oldy3 = m.y3
    return m.y4
