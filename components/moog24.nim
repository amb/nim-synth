# Moog filter
# https://www.musicdsp.org/en/latest/Filters/24-moog-vcf.html

# --Init
# cutoff = cutoff freq in Hz
# fs = sampling frequency //(e.g. 44100Hz)
# res = resonance [0 - 1] //(minimum - maximum)

# f = 2 * cutoff / fs; //[0 - 1]
# k = 3.6*f - 1.6*f*f -1; //(Empirical tunning)
# p = (k+1)*0.5;
# scale = e^((1-p)*1.386249;
# r = res*scale;
# y4 = output;

# y1=y2=y3=y4=oldx=oldy1=oldy2=oldy3=0;

# --Loop
# --Inverted feed back for corner peaking
# x = input - r*y4;

# --Four cascaded onepole filters (bilinear transform)
# y1=x*p + oldx*p - k*y1;
# y2=y1*p+oldy1*p - k*y2;
# y3=y2*p+oldy2*p - k*y3;
# y4=y3*p+oldy3*p - k*y4;

# --Clipper band limited sigmoid
# y4 = y4 - (y4^3)/6;

# oldx = x;
# oldy1 = y1;
# oldy2 = y2;
# oldy3 = y3;

import math

type MoogVCF* = object
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
    m.cutoff = cutoff
    m.fs = fs
    m.res = res
    m.f = 2 * cutoff / fs
    # alt tuning: k=2*sin(f*pi/2)-1
    m.k = 3.6 * m.f - 1.6 * m.f * m.f - 1
    m.p = (m.k + 1) * 0.5
    m.scale = math.exp((1 - m.p) * 1.386249)
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
