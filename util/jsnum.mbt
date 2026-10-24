// JavaScript number semantics that Vega relies on and MoonBit does not guarantee:
// `String(x)`, `Math.round` and the `~~x` truncation. Behavior is verified against
// Node by the numfmt fixtures.

///|
let two_pow_32 : Double = 4294967296.0

///|
let two_pow_31 : Double = 2147483648.0

///|
let two_pow_52 : Double = 4503599627370496.0

///|
/// `String(x)` in JavaScript: shortest round-trip digits, `-0` prints as `0`,
/// exponent notation outside 1e-6 <= |x| < 1e21.
pub fn js_number_to_string(x : Double) -> String {
  if x.is_nan() {
    "NaN"
  } else if x.is_pos_inf() {
    "Infinity"
  } else if x.is_neg_inf() {
    "-Infinity"
  } else if x == 0.0 {
    "0"
  } else {
    x.to_string()
  }
}

///|
/// `Math.round(x)`: nearest integer, ties toward +Infinity, `-0` preserved for
/// -0.5 <= x < 0.
pub fn js_round(x : Double) -> Double {
  if x.is_nan() || x.is_inf() || x.abs() >= two_pow_52 {
    return x
  }
  let f = x.floor()
  let r = if x - f >= 0.5 { f + 1.0 } else { f }
  if r == 0.0 && (x < 0.0 || 1.0 / x < 0.0) {
    -0.0
  } else {
    r
  }
}

///|
/// `~~x`: truncate toward zero and wrap to a signed 32-bit integer; NaN and
/// infinities become 0.
pub fn js_to_int32(x : Double) -> Int32 {
  if x.is_nan() || x.is_inf() {
    return 0
  }
  let mut t = x.trunc().mod(two_pow_32)
  if t >= two_pow_31 {
    t = t - two_pow_32
  } else if t < -two_pow_31 {
    t = t + two_pow_32
  }
  t.to_int()
}

///|
/// `Math.max(a, b)`: NaN if either side is NaN; `+0` is larger than `-0`.
pub fn js_max(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a == 0.0 && b == 0.0 {
    if 1.0 / a > 0.0 {
      a
    } else {
      b
    }
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// `Math.min(a, b)`: NaN if either side is NaN; `-0` is smaller than `+0`.
pub fn js_min(a : Double, b : Double) -> Double {
  if a.is_nan() || b.is_nan() {
    @double.not_a_number
  } else if a == 0.0 && b == 0.0 {
    if 1.0 / a < 0.0 {
      a
    } else {
      b
    }
  } else if a < b {
    a
  } else {
    b
  }
}
