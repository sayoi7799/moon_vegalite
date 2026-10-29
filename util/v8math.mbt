// Math.sin, cos, asin, acos, atan and atan2 that agree bit for bit with V8 (Node, Chrome).
//
// `sin`, `cos`, `asin` and `atan` come from moon_rough's `jsmath` (ports of V8's fdlibm); `acos` and
// `atan2` are ports of fdlibm's e_acos.c and e_atan2.c as V8 ships them. The platform libm differs from
// V8 by an ulp for some arguments, which would change the digits of a path (d3-arc: `arc` draws with
// all of them), so none of it is used. The tests compare the results with Node's `Math` bit by bit.

///|
pub fn v8_sin(x : Double) -> Double {
  @jsmath.sin(x)
}

///|
pub fn v8_cos(x : Double) -> Double {
  @jsmath.cos(x)
}

///|
pub fn v8_asin(x : Double) -> Double {
  @jsmath.asin(x)
}

///|
pub fn v8_atan(x : Double) -> Double {
  @jsmath.atan(x)
}

///|
fn with_low_word_zero(x : Double) -> Double {
  (x.reinterpret_as_uint64() >> 32 << 32).reinterpret_as_double()
}

///|
/// `Math.acos`.
pub fn v8_acos(x : Double) -> Double {
  let pio2_hi = 1.57079632679489655800e+00
  let pio2_lo = 6.12323399573676603587e-17
  let pi = 3.14159265358979311600e+00
  let ps0 = 1.66666666666666657415e-01
  let ps1 = -3.25565818622400915405e-01
  let ps2 = 2.01212532134862925881e-01
  let ps3 = -4.00555345006794114027e-02
  let ps4 = 7.91534994289814532176e-04
  let ps5 = 3.47933107596021167570e-05
  let qs1 = -2.40339491173441421878e+00
  let qs2 = 2.02094576023350569471e+00
  let qs3 = -6.88283971605453293030e-01
  let qs4 = 7.70381505559019352791e-02
  let hx = high_word(x)
  let ix = hx & 0x7fffffff
  if ix >= 0x3ff00000 {
    // |x| >= 1
    let lx = low_word(x)
    if ((ix - 0x3ff00000) | lx) == 0 {
      return if hx > 0 { 0.0 } else { pi + 2.0 * pio2_lo }
    }
    return @double.not_a_number
  }
  if ix < 0x3fe00000 {
    // |x| < 0.5
    if ix <= 0x3c600000 {
      return pio2_hi + pio2_lo
    }
    let z = x * x
    let p = z * (ps0 + z * (ps1 + z * (ps2 + z * (ps3 + z * (ps4 + z * ps5)))))
    let q = 1.0 + z * (qs1 + z * (qs2 + z * (qs3 + z * qs4)))
    let r = p / q
    return pio2_hi - (x - (pio2_lo - x * r))
  } else if hx < 0 {
    // x < -0.5
    let z = (1.0 + x) * 0.5
    let p = z * (ps0 + z * (ps1 + z * (ps2 + z * (ps3 + z * (ps4 + z * ps5)))))
    let q = 1.0 + z * (qs1 + z * (qs2 + z * (qs3 + z * qs4)))
    let s = z.sqrt()
    let r = p / q
    let w = r * s - pio2_lo
    return pi - 2.0 * (s + w)
  } else {
    // x > 0.5
    let z = (1.0 - x) * 0.5
    let s = z.sqrt()
    let df = with_low_word_zero(s)
    let c = (z - df * df) / (s + df)
    let p = z * (ps0 + z * (ps1 + z * (ps2 + z * (ps3 + z * (ps4 + z * ps5)))))
    let q = 1.0 + z * (qs1 + z * (qs2 + z * (qs3 + z * qs4)))
    let r = p / q
    let w = r * s + c
    return 2.0 * (df + w)
  }
}

///|
/// `Math.atan2(y, x)`.
pub fn v8_atan2(y : Double, x : Double) -> Double {
  let pi_o_4 = 7.8539816339744827900e-01
  let pi_o_2 = 1.5707963267948965580e+00
  let pi = 3.1415926535897931160e+00
  let pi_lo = 1.2246467991473531772e-16
  let hx = high_word(x)
  let lx = low_word(x)
  let ix = hx & 0x7fffffff
  let hy = high_word(y)
  let ly = low_word(y)
  let iy = hy & 0x7fffffff
  if x.is_nan() || y.is_nan() {
    return x + y
  }
  if ((hx - 0x3ff00000) | lx) == 0 {
    return v8_atan(y) // x = 1.0
  }
  // 2 * sign(x) + sign(y)
  let m = ((hy >> 31) & 1) | ((hx >> 30) & 2)
  // y = 0
  if (iy | ly) == 0 {
    return match m {
      0 | 1 => y
      2 => pi
      _ => -pi
    }
  }
  // x = 0
  if (ix | lx) == 0 {
    return if hy < 0 { -pi_o_2 } else { pi_o_2 }
  }
  // x is infinite
  if ix == 0x7ff00000 {
    if iy == 0x7ff00000 {
      return match m {
        0 => pi_o_4
        1 => -pi_o_4
        2 => 3.0 * pi_o_4
        _ => -3.0 * pi_o_4
      }
    } else {
      return match m {
        0 => 0.0
        1 => -0.0
        2 => pi
        _ => -pi
      }
    }
  }
  // y is infinite
  if iy == 0x7ff00000 {
    return if hy < 0 { -pi_o_2 } else { pi_o_2 }
  }
  // |y / x|
  let k = (iy - ix) >> 20
  let mut mm = m
  let z = if k > 60 {
    mm = mm & 1
    pi_o_2 + 0.5 * pi_lo
  } else if hx < 0 && k < -60 {
    0.0
  } else {
    v8_atan((y / x).abs())
  }
  match mm {
    0 => z
    1 => -z
    2 => pi - (z - pi_lo)
    _ => z - pi_lo - pi
  }
}
