// JavaScript's Number#toFixed, #toExponential and #toPrecision.
//
// The ECMAScript spec rounds the *exact* binary value (ties pick the larger
// result), so these functions expand the double into its exact decimal digits
// with a small base-1e9 big integer instead of going through floating point.

///|
/// Significant decimal digits of a positive finite number (no leading zeros,
/// no trailing zeros) and the scientific exponent of the first digit.
priv struct Decimal {
  digits : String
  exp : Int32
}

///|
fn sub(s : String, start : Int32, end : Int32) -> String {
  s.unsafe_substring(start~, end~)
}

///|
fn zeros(n : Int32) -> String {
  if n <= 0 {
    ""
  } else {
    "0".repeat(n)
  }
}

///|
fn is_digit_char(c : UInt16, ch : Char) -> Bool {
  c.to_int() == ch.to_int()
}

///|
fn mul_small(limbs : Array[Int32], k : Int32) -> Unit {
  let base = 1000000000L
  let mut carry = 0L
  for i in 0..<limbs.length() {
    let v = limbs[i].to_int64() * k.to_int64() + carry
    limbs[i] = (v % base).to_int()
    carry = v / base
  }
  while carry > 0L {
    limbs.push((carry % base).to_int())
    carry = carry / base
  }
}

///|
fn limbs_to_string(limbs : Array[Int32]) -> String {
  let out = StringBuilder()
  let mut i = limbs.length() - 1
  out.write_string(limbs[i].to_string())
  i = i - 1
  while i >= 0 {
    let part = limbs[i].to_string()
    out.write_string(zeros(9 - part.length()))
    out.write_string(part)
    i = i - 1
  }
  out.to_string()
}

///|
fn strip_trailing_zeros(s : String) -> String {
  let mut end = s.length()
  while end > 1 && is_digit_char(s.at(end - 1), '0') {
    end = end - 1
  }
  sub(s, 0, end)
}

///|
/// Exact decimal expansion of a positive finite double.
fn exact_decimal(x : Double) -> Decimal {
  let bits = x.reinterpret_as_uint64()
  let biased = ((bits >> 52) & 0x7FFUL).to_int()
  let frac = bits & 0xFFFFFFFFFFFFFUL
  let (m, e) = if biased == 0 {
    (frac, -1074)
  } else {
    (frac | 0x10000000000000UL, biased - 1075)
  }
  let base = 1000000000UL
  let limbs = [
    (m % base).to_int(),
    (m / base % base).to_int(),
    (m / (base * base)).to_int(),
  ]
  while limbs.length() > 1 && limbs[limbs.length() - 1] == 0 {
    ignore(limbs.pop())
  }
  if e >= 0 {
    let mut k = e
    while k >= 29 {
      mul_small(limbs, 536870912)
      k = k - 29
    }
    if k > 0 {
      mul_small(limbs, 1 << k)
    }
    let s = limbs_to_string(limbs)
    { digits: strip_trailing_zeros(s), exp: s.length() - 1, }
  } else {
    let mut k = -e
    let total = k
    while k >= 13 {
      mul_small(limbs, 1220703125)
      k = k - 13
    }
    let mut p = 1
    for _ in 0..<k {
      p = p * 5
    }
    if p > 1 {
      mul_small(limbs, p)
    }
    let s = limbs_to_string(limbs)
    { digits: strip_trailing_zeros(s), exp: s.length() - 1 - total, }
  }
}

///|
fn parse_signed_int(s : String) -> Int32 {
  let r : Int32 = try {
    if s.has_prefix("-") {
      -(@string.from_str(sub(s, 1, s.length())) : Int32)
    } else if s.has_prefix("+") {
      @string.from_str(sub(s, 1, s.length()))
    } else {
      @string.from_str(s)
    }
  } catch {
    _ => 0
  }
  r
}

///|
/// Shortest round-trip digits (what `String(x)` prints), for positive finite x.
fn shortest_decimal(x : Double) -> Decimal {
  let s = @util.js_number_to_string(x)
  let (mant, ex) = match s.find("e") {
    Some(i) => (sub(s, 0, i), parse_signed_int(sub(s, i + 1, s.length())))
    None => (s, 0)
  }
  let (ip, fp) = match mant.find(".") {
    Some(i) => (sub(mant, 0, i), sub(mant, i + 1, mant.length()))
    None => (mant, "")
  }
  let all = ip + fp
  let mut lz = 0
  while lz < all.length() - 1 && is_digit_char(all.at(lz), '0') {
    lz = lz + 1
  }
  let digits = strip_trailing_zeros(sub(all, lz, all.length()))
  { digits, exp: ip.length() - 1 - lz + ex, }
}

///|
/// Add one to a string of decimal digits; may grow by one digit.
fn increment_digits(s : String) -> String {
  let cs = s.to_array()
  let mut i = cs.length() - 1
  while i >= 0 {
    if cs[i] == '9' {
      cs[i] = '0'
      i = i - 1
    } else {
      cs[i] = (cs[i].to_int() + 1).unsafe_to_char()
      return String::from_array(cs)
    }
  }
  "1" + String::from_array(cs)
}

///|
/// Round to `n` significant digits (n >= 1). Ties go up: with an exact
/// expansion, "next digit >= 5" is the same as "remainder >= half".
/// Returns exactly `n` digits and the (possibly bumped) exponent.
fn round_sig(d : Decimal, n : Int32) -> (String, Int32) {
  let len = d.digits.length()
  if len <= n {
    return (d.digits + zeros(n - len), d.exp)
  }
  let head = sub(d.digits, 0, n)
  if d.digits.at(n).to_int() >= '5'.to_int() {
    let inc = increment_digits(head)
    if inc.length() > n {
      (sub(inc, 0, n), d.exp + 1)
    } else {
      (inc, d.exp)
    }
  } else {
    (head, d.exp)
  }
}

///|
fn sign_prefix(x : Double) -> String {
  if x < 0.0 {
    "-"
  } else {
    ""
  }
}

///|
fn non_finite(x : Double) -> String? {
  if x.is_nan() {
    Some("NaN")
  } else if x.is_pos_inf() {
    Some("Infinity")
  } else if x.is_neg_inf() {
    Some("-Infinity")
  } else {
    None
  }
}

///|
fn exp_suffix(e : Int32) -> String {
  "e" +
  (if e >= 0 { "+" } else { "-" }) +
  (if e >= 0 { e } else { -e }).to_string()
}

///|
/// `x.toFixed(f)` for 0 <= f <= 100.
pub fn to_fixed(x : Double, f : Int32) -> String {
  match non_finite(x) {
    Some(s) => return s
    None => ()
  }
  let ax = x.abs()
  if ax >= 1.0e21 {
    return @util.js_number_to_string(x)
  }
  // r = round(ax * 10^f) as a string of decimal digits
  let r = if ax == 0.0 {
    "0"
  } else {
    let d = exact_decimal(ax)
    let keep = d.exp + f + 1
    if keep < 0 {
      "0"
    } else if keep == 0 {
      if d.digits.at(0).to_int() >= '5'.to_int() {
        "1"
      } else {
        "0"
      }
    } else {
      let (ds, e2) = round_sig(d, keep)
      // On carry round_sig keeps `keep` digits and bumps the exponent: the
      // integer ax * 10^f then has one more (zero) digit.
      if e2 > d.exp {
        ds + "0"
      } else {
        ds
      }
    }
  }
  let body = if f == 0 {
    r
  } else {
    let padded = zeros(f + 1 - r.length()) + r
    let n = padded.length()
    sub(padded, 0, n - f) + "." + sub(padded, n - f, n)
  }
  sign_prefix(x) + body
}

///|
fn exponential_from(ds : String, e : Int32) -> String {
  let mantissa = if ds.length() > 1 {
    sub(ds, 0, 1) + "." + sub(ds, 1, ds.length())
  } else {
    ds
  }
  mantissa + exp_suffix(e)
}

///|
/// `x.toExponential(f)` for 0 <= f <= 100.
pub fn to_exponential(x : Double, f : Int32) -> String {
  match non_finite(x) {
    Some(s) => return s
    None => ()
  }
  let ax = x.abs()
  if ax == 0.0 {
    return sign_prefix(x) + exponential_from(zeros(f + 1), 0)
  }
  let (ds, e) = round_sig(exact_decimal(ax), f + 1)
  sign_prefix(x) + exponential_from(ds, e)
}

///|
/// `x.toExponential()`: as many digits as necessary to identify the number.
pub fn to_exponential_shortest(x : Double) -> String {
  match non_finite(x) {
    Some(s) => return s
    None => ()
  }
  let ax = x.abs()
  if ax == 0.0 {
    return sign_prefix(x) + "0e+0"
  }
  let d = shortest_decimal(ax)
  sign_prefix(x) + exponential_from(d.digits, d.exp)
}

///|
/// `x.toPrecision(p)` for 1 <= p <= 100.
pub fn to_precision(x : Double, p : Int32) -> String {
  match non_finite(x) {
    Some(s) => return s
    None => ()
  }
  let ax = x.abs()
  let (ds, e) = if ax == 0.0 {
    (zeros(p), 0)
  } else {
    round_sig(exact_decimal(ax), p)
  }
  let body = if e < -6 || e >= p {
    exponential_from(ds, e)
  } else if e == p - 1 {
    ds
  } else if e >= 0 {
    sub(ds, 0, e + 1) + "." + sub(ds, e + 1, ds.length())
  } else {
    "0." + zeros(-(e + 1)) + ds
  }
  sign_prefix(x) + body
}

///|
/// d3's `formatDecimalParts`: the significant digits and scientific exponent
/// of |x| with `p` significant digits (p > 0), or the shortest digits when `p`
/// is 0. None for NaN and +-Infinity. Zero has coefficient "0" (padded to `p`
/// digits), as in the d3-format 3.1.0 bundled with Vega.
pub fn decimal_parts(x : Double, p : Int32) -> (String, Int32)? {
  if x.is_nan() || x.is_inf() {
    return None
  }
  let ax = x.abs()
  if ax == 0.0 {
    return Some((zeros(if p > 0 { p } else { 1 }), 0))
  }
  if p > 0 {
    Some(round_sig(exact_decimal(ax), p))
  } else {
    let d = shortest_decimal(ax)
    Some((d.digits, d.exp))
  }
}
