// Bit-compatible ports of the V8 / fdlibm implementations of Math.log, Math.log10
// and Math.pow(10, k), so that results do not depend on the platform libm.
//
// Adapted from fdlibm (http://www.netlib.org/fdlibm) via V8's src/base/ieee754.cc.
// ====================================================
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//
// Developed at SunSoft, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================

///|
let ln2_hi : Double = 6.93147180369123816490e-01

///|
let ln2_lo : Double = 1.90821492927058770002e-10

///|
let two54 : Double = 1.80143985094819840000e+16

///|
let lg1 : Double = 6.666666666666735130e-01

///|
let lg2 : Double = 3.999999999940941908e-01

///|
let lg3 : Double = 2.857142874366239149e-01

///|
let lg4 : Double = 2.222219843214978396e-01

///|
let lg5 : Double = 1.818357216161805012e-01

///|
let lg6 : Double = 1.531383769920937332e-01

///|
let lg7 : Double = 1.479819860511658591e-01

///|
let ivln10 : Double = 4.34294481903251816668e-01

///|
let log10_2hi : Double = 3.01029995663611771306e-01

///|
let log10_2lo : Double = 3.69423907715893078616e-13

///|
/// The more significant 32 bits (as a signed Int).
fn high_word(x : Double) -> Int32 {
  (x.reinterpret_as_uint64() >> 32).to_int()
}

///|
/// The less significant 32 bits (bit pattern in a signed Int).
fn low_word(x : Double) -> Int32 {
  (x.reinterpret_as_uint64() & 0xFFFFFFFFUL).to_int()
}

///|
fn from_words(hi : Int32, lo : Int32) -> Double {
  let h = hi.reinterpret_as_uint().to_uint64()
  let l = lo.reinterpret_as_uint().to_uint64()
  ((h << 32) | l).reinterpret_as_double()
}

///|
/// `Math.log(x)` exactly as computed by V8 (fdlibm `__ieee754_log`).
pub fn js_log(x0 : Double) -> Double {
  let mut x = x0
  let mut hx = high_word(x)
  let lx = low_word(x)
  let mut k = 0
  if hx < 0x00100000 {
    if ((hx & 0x7FFFFFFF) | lx) == 0 {
      return @double.neg_infinity
    }
    if hx < 0 {
      return @double.not_a_number
    }
    k = k - 54
    x = x * two54
    hx = high_word(x)
  }
  if hx >= 0x7FF00000 {
    return x + x
  }
  k = k + ((hx >> 20) - 1023)
  hx = hx & 0x000FFFFF
  let i = (hx + 0x95F64) & 0x100000
  x = from_words(hx | (i ^ 0x3FF00000), low_word(x))
  k = k + (i >> 20)
  let f = x - 1.0
  if (0x000FFFFF & (2 + hx)) < 3 {
    if f == 0.0 {
      if k == 0 {
        return 0.0
      } else {
        let dk = k.to_double()
        return dk * ln2_hi + dk * ln2_lo
      }
    }
    let r = f * f * (0.5 - 0.33333333333333333 * f)
    if k == 0 {
      return f - r
    } else {
      let dk = k.to_double()
      return dk * ln2_hi - (r - dk * ln2_lo - f)
    }
  }
  let s = f / (2.0 + f)
  let dk = k.to_double()
  let z = s * s
  let mut i2 = hx - 0x6147A
  let w = z * z
  let j = 0x6B851 - hx
  let t1 = w * (lg2 + w * (lg4 + w * lg6))
  let t2 = z * (lg1 + w * (lg3 + w * (lg5 + w * lg7)))
  i2 = i2 | j
  let r = t2 + t1
  if i2 > 0 {
    let hfsq = 0.5 * f * f
    if k == 0 {
      f - (hfsq - s * (hfsq + r))
    } else {
      dk * ln2_hi - (hfsq - (s * (hfsq + r) + dk * ln2_lo) - f)
    }
  } else if k == 0 {
    f - s * (f - r)
  } else {
    dk * ln2_hi - (s * (f - r) - dk * ln2_lo - f)
  }
}

///|
/// `Math.log10(x)` exactly as computed by V8 (fdlibm `__ieee754_log10`).
pub fn js_log10(x0 : Double) -> Double {
  let mut x = x0
  let mut hx = high_word(x)
  let mut lx = low_word(x)
  let mut k = 0
  if hx < 0x00100000 {
    if ((hx & 0x7FFFFFFF) | lx) == 0 {
      return @double.neg_infinity
    }
    if hx < 0 {
      return @double.not_a_number
    }
    k = k - 54
    x = x * two54
    hx = high_word(x)
    lx = low_word(x)
  }
  if hx >= 0x7FF00000 {
    return x + x
  }
  if hx == 0x3FF00000 && lx == 0 {
    return 0.0
  }
  k = k + ((hx >> 20) - 1023)
  let i = if k < 0 { 1 } else { 0 }
  hx = (hx & 0x000FFFFF) | ((0x3FF - i) << 20)
  let y = (k + i).to_double()
  x = from_words(hx, lx)
  let z = y * log10_2lo + ivln10 * js_log(x)
  z + y * log10_2hi
}

///|
/// `Math.pow(10, k)` as computed by V8. Exact table for integer exponents in
/// [-330, 310]; other exponents fall back to the platform `pow`.
pub fn js_pow10(k : Double) -> Double {
  if k.is_nan() {
    return k
  }
  let ki = k.to_int()
  if ki.to_double() == k && ki >= pow10_min_exp && ki <= pow10_max_exp {
    pow10_bits[ki - pow10_min_exp].reinterpret_as_double()
  } else {
    @math.pow(10.0, k)
  }
}
