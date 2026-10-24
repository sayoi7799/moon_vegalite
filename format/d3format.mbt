// Port of d3-format 3.1.2 (ISC license), en-US locale, as configured by Vega.
// https://github.com/d3/d3-format
//
// Differences from the JavaScript original are limited to the type system:
// the module-level `prefixExponent` is returned alongside the formatted
// string, and invalid specifiers raise `FormatError` instead of `Error`.

///|
pub(all) suberror FormatError {
  FormatError(String)
}

///|
/// `[[fill]align][sign][symbol][0][width][,][.precision][~][type]`
pub struct FormatSpecifier {
  fill : String
  align : String
  sign : String
  symbol : String
  zero : Bool
  width : Int32?
  comma : Bool
  precision : Int32?
  trim : Bool
  kind : String
}

///|
let int_max : Int32 = 2147483647

///|
let minus_sign : String = "\u{2212}"

///|
let si_prefixes : Array[String] = [
  "y", "z", "a", "f", "p", "n", "\u{b5}", "m", "", "k", "M", "G", "T", "P", "E",
  "Z", "Y",
]

///|
fn is_align_char(c : Char) -> Bool {
  c == '<' || c == '>' || c == '=' || c == '^'
}

///|
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_ascii_letter(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
/// Parse a d3 format specifier string.
pub fn parse_specifier(s : String) -> FormatSpecifier raise FormatError {
  let cs = s.to_array()
  let n = cs.length()
  let mut i = 0
  let mut fill = " "
  let mut align = ">"
  if n >= 2 && is_align_char(cs[1]) {
    fill = cs[0].to_string()
    align = cs[1].to_string()
    i = 2
  } else if n >= 1 && is_align_char(cs[0]) {
    align = cs[0].to_string()
    i = 1
  }
  let mut sign = "-"
  if i < n && (cs[i] == '+' || cs[i] == '-' || cs[i] == '(' || cs[i] == ' ') {
    sign = cs[i].to_string()
    i = i + 1
  }
  let mut symbol = ""
  if i < n && (cs[i] == '$' || cs[i] == '#') {
    symbol = cs[i].to_string()
    i = i + 1
  }
  let mut zero = false
  if i < n && cs[i] == '0' {
    zero = true
    i = i + 1
  }
  let mut width : Int32? = None
  let w_start = i
  while i < n && is_ascii_digit(cs[i]) {
    i = i + 1
  }
  if i > w_start {
    width = Some(parse_digits(cs, w_start, i))
  }
  let mut comma = false
  if i < n && cs[i] == ',' {
    comma = true
    i = i + 1
  }
  let mut precision : Int32? = None
  if i + 1 < n && cs[i] == '.' && is_ascii_digit(cs[i + 1]) {
    let p_start = i + 1
    i = p_start
    while i < n && is_ascii_digit(cs[i]) {
      i = i + 1
    }
    precision = Some(parse_digits(cs, p_start, i))
  }
  let mut trim = false
  if i < n && cs[i] == '~' {
    trim = true
    i = i + 1
  }
  let mut kind = ""
  if i < n && (is_ascii_letter(cs[i]) || cs[i] == '%') {
    kind = cs[i].to_string()
    i = i + 1
  }
  if i != n {
    raise FormatError("invalid format: " + s)
  }
  { fill, align, sign, symbol, zero, width, comma, precision, trim, kind, }
}

///|
fn parse_digits(cs : Array[Char], start : Int32, end : Int32) -> Int32 {
  let mut v = 0
  for k in start..<end {
    if v < 100000000 {
      v = v * 10 + (cs[k].to_int() - '0'.to_int())
    }
  }
  v
}

///|
/// `FormatSpecifier.prototype.toString`: the canonical specifier string.
pub fn FormatSpecifier::to_spec_string(self : FormatSpecifier) -> String {
  let out = StringBuilder()
  out.write_string(self.fill)
  out.write_string(self.align)
  out.write_string(self.sign)
  out.write_string(self.symbol)
  if self.zero {
    out.write_string("0")
  }
  match self.width {
    Some(w) =>
      out.write_string(@util.js_max(1.0, w.to_double()).to_int().to_string())
    None => ()
  }
  if self.comma {
    out.write_string(",")
  }
  match self.precision {
    Some(p) => out.write_string("." + (if p < 0 { 0 } else { p }).to_string())
    None => ()
  }
  if self.trim {
    out.write_string("~")
  }
  out.write_string(self.kind)
  out.to_string()
}

///|
fn is_valid_kind(kind : String) -> Bool {
  kind == "%" ||
  kind == "b" ||
  kind == "c" ||
  kind == "d" ||
  kind == "e" ||
  kind == "f" ||
  kind == "g" ||
  kind == "o" ||
  kind == "p" ||
  kind == "r" ||
  kind == "s" ||
  kind == "X" ||
  kind == "x"
}

///|
/// d3's `formatTrim`: trims insignificant zeros, e.g. 1.2000k becomes 1.2k.
fn format_trim(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  let mut i0 = -1
  let mut i1 = -1
  let mut i = 1
  while i < n {
    let c = cs[i]
    if c == '.' {
      i0 = i
      i1 = i
    } else if c == '0' {
      if i0 == 0 {
        i0 = i
      }
      i1 = i
    } else if c >= '1' && c <= '9' {
      if i0 > 0 {
        i0 = 0
      }
    } else {
      break
    }
    i = i + 1
  }
  if i0 > 0 {
    sub(s, 0, i0) + sub(s, i1 + 1, s.length())
  } else {
    s
  }
}

///|
fn format_decimal(x : Double) -> String {
  let r = @util.js_round(x)
  if r.is_inf() {
    return "\u{221e}"
  }
  if r.abs() >= 1.0e21 {
    let d = shortest_decimal(r.abs())
    return d.digits + zeros(d.exp + 1 - d.digits.length())
  }
  @util.js_number_to_string(r)
}

///|
/// `Math.round(x).toString(radix)` for non-negative x. Values beyond Int64 are
/// converted exactly with a base-1e9 big integer.
fn to_radix(x : Double, radix : Int32) -> String {
  let r = @util.js_round(x)
  if r.is_inf() || r.is_nan() {
    return @util.js_number_to_string(r)
  }
  let digits = "0123456789abcdef".to_array()
  let out : Array[Char] = []
  if r < 9.0e18 {
    let mut v = r.to_int64()
    if v == 0L {
      return "0"
    }
    let rd = radix.to_int64()
    while v > 0L {
      out.push(digits[(v % rd).to_int()])
      v = v / rd
    }
  } else {
    // exact integer digits -> little-endian base-1e9 limbs
    let d = exact_decimal(r)
    let text = d.digits + zeros(d.exp + 1 - d.digits.length())
    let limbs : Array[Int32] = []
    let mut end = text.length()
    while end > 0 {
      let start = if end - 9 > 0 { end - 9 } else { 0 }
      limbs.push(@string.from_str(sub(text, start, end)) catch { _ => 0 })
      end = start
    }
    while limbs.length() > 0 {
      // divide limbs by radix, keeping the remainder
      let mut rem = 0L
      let mut i = limbs.length() - 1
      while i >= 0 {
        let cur = rem * 1000000000L + limbs[i].to_int64()
        limbs[i] = (cur / radix.to_int64()).to_int()
        rem = cur % radix.to_int64()
        i = i - 1
      }
      out.push(digits[rem.to_int()])
      while limbs.length() > 0 && limbs[limbs.length() - 1] == 0 {
        ignore(limbs.pop())
      }
    }
  }
  out.rev_in_place()
  String::from_array(out)
}

///|
/// d3's `formatRounded`.
fn format_rounded(x : Double, p : Int32) -> String {
  match decimal_parts(x, p) {
    None => @util.js_number_to_string(x)
    Some((coefficient, exponent)) =>
      if exponent < 0 {
        "0." + zeros(-exponent - 1) + coefficient
      } else if coefficient.length() > exponent + 1 {
        sub(coefficient, 0, exponent + 1) +
        "." +
        sub(coefficient, exponent + 1, coefficient.length())
      } else {
        coefficient + zeros(exponent - coefficient.length() + 1)
      }
  }
}

///|
fn clamp_prefix_exponent(e : Int32) -> Int32 {
  // Math.max(-8, Math.min(8, Math.floor(exponent / 3))) * 3
  let q = (e.to_double() / 3.0).floor().to_int()
  (if q > 8 { 8 } else if q < -8 { -8 } else { q }) * 3
}

///|
/// d3's `formatPrefixAuto`: returns the digits and the SI prefix exponent.
fn format_prefix_auto(x : Double, p : Int32) -> (String, Int32?) {
  match decimal_parts(x, p) {
    None => (@util.js_number_to_string(x), None)
    Some((coefficient, exponent)) => {
      let pe = clamp_prefix_exponent(exponent)
      let i = exponent - pe + 1
      let n = coefficient.length()
      let s = if i == n {
        coefficient
      } else if i > n {
        coefficient + zeros(i - n)
      } else if i > 0 {
        sub(coefficient, 0, i) + "." + sub(coefficient, i, n)
      } else {
        let more = match
          decimal_parts(x, @util.js_max(0.0, (p + i - 1).to_double()).to_int()) {
          Some((c, _)) => c
          None => ""
        }
        "0." + zeros(-i) + more
      }
      (s, Some(pe))
    }
  }
}

///|
fn format_type(kind : String, x : Double, p : Int32) -> (String, Int32?) {
  match kind {
    "%" => (to_fixed(x * 100.0, p), None)
    "b" => (to_radix(x, 2), None)
    "c" => (@util.js_number_to_string(x), None)
    "d" => (format_decimal(x), None)
    "e" => (to_exponential(x, p), None)
    "f" => (to_fixed(x, p), None)
    "g" => (to_precision(x, p), None)
    "o" => (to_radix(x, 8), None)
    "p" => (format_rounded(x * 100.0, p), None)
    "r" => (format_rounded(x, p), None)
    "s" => format_prefix_auto(x, p)
    "X" => (to_radix(x, 16).to_upper(), None)
    "x" => (to_radix(x, 16), None)
    _ => (@util.js_number_to_string(x), None)
  }
}

///|
/// JavaScript's `+s === 0` for the numeric strings d3 produces.
fn is_numeric_zero(s : String) -> Bool {
  if s == "" {
    return true
  }
  let v : Double = @string.from_str(s) catch { _ => @double.not_a_number }
  v == 0.0
}

///|
/// d3's `formatGroup` for the en-US locale (groups of 3, separated by ",").
fn group_digits(value : String, width : Int32) -> String {
  let mut i = value.length()
  let parts : Array[String] = []
  let mut g = 3
  let mut length = 0
  while i > 0 && g > 0 {
    if length + g + 1 > width {
      g = if width - length > 1 { width - length } else { 1 }
    }
    let start = if i - g > 0 { i - g } else { 0 }
    parts.push(sub(value, start, i))
    i = i - g
    length = length + g + 1
    if length > width {
      break
    }
  }
  parts.rev_in_place()
  parts.join(",")
}

///|
fn new_format(spec : FormatSpecifier) -> (Double) -> String {
  let (kind, comma, precision0, trim) = if spec.kind == "n" {
    ("g", true, spec.precision, spec.trim)
  } else if !is_valid_kind(spec.kind) {
    (
      "g",
      spec.comma,
      match spec.precision {
        None => Some(12)
        p => p
      },
      true,
    )
  } else {
    (spec.kind, spec.comma, spec.precision, spec.trim)
  }
  let (zero, fill, align) = if spec.zero ||
    (spec.fill == "0" && spec.align == "=") {
    (true, "0", "=")
  } else {
    (false, spec.fill, spec.align)
  }
  let sign = spec.sign
  let symbol = spec.symbol
  let width = spec.width
  let prefix = if symbol == "$" {
    "$"
  } else if symbol == "#" && "boxX".contains(kind) {
    "0" + kind.to_lower()
  } else {
    ""
  }
  let suffix = if symbol == "$" {
    ""
  } else if "%p".contains(kind) {
    "%"
  } else {
    ""
  }
  let maybe_suffix = "defgprs%".contains(kind)
  let precision = match precision0 {
    None => 6
    Some(p) =>
      if "gprs".contains(kind) {
        if p < 1 {
          1
        } else if p > 21 {
          21
        } else {
          p
        }
      } else if p < 0 {
        0
      } else if p > 20 {
        20
      } else {
        p
      }
  }
  fn(input : Double) {
    let mut value_prefix = prefix
    let mut value_suffix = suffix
    let mut value = ""
    if kind == "c" {
      value_suffix = @util.js_number_to_string(input) + value_suffix
    } else {
      let mut negative = input < 0.0 || 1.0 / input < 0.0
      let (body0, pe) = if input.is_nan() {
        ("NaN", None)
      } else {
        format_type(kind, input.abs(), precision)
      }
      value = if trim { format_trim(body0) } else { body0 }
      if negative && is_numeric_zero(value) && sign != "+" {
        negative = false
      }
      value_prefix = (if negative {
          if sign == "(" {
            sign
          } else {
            minus_sign
          }
        } else if sign == "-" || sign == "(" {
          ""
        } else {
          sign
        }) +
        value_prefix
      value_suffix = (match pe {
          Some(e) if kind == "s" && value != "NaN" => si_prefixes[8 + e / 3]
          _ => ""
        }) +
        value_suffix +
        (if negative && sign == "(" { ")" } else { "" })
      if maybe_suffix {
        let cs = value.to_array()
        for i in 0..<cs.length() {
          let c = cs[i]
          if !is_ascii_digit(c) {
            value_suffix = (if c == '.' {
                "." + sub(value, i + 1, value.length())
              } else {
                sub(value, i, value.length())
              }) +
              value_suffix
            value = sub(value, 0, i)
            break
          }
        }
      }
    }
    if comma && !zero {
      value = group_digits(value, int_max)
    }
    let length = value_prefix.length() + value.length() + value_suffix.length()
    let mut padding = match width {
      Some(w) if length < w => fill.repeat(w - length)
      _ => ""
    }
    if comma && zero {
      let w = match width {
        Some(w) => w
        None => int_max
      }
      value = group_digits(
        padding + value,
        if padding.length() > 0 {
          w - value_suffix.length()
        } else {
          int_max
        },
      )
      padding = ""
    }
    match align {
      "<" => value_prefix + value + value_suffix + padding
      "=" => value_prefix + padding + value + value_suffix
      "^" => {
        let half = padding.length() >> 1
        sub(padding, 0, half) +
        value_prefix +
        value +
        value_suffix +
        sub(padding, half, padding.length())
      }
      _ => padding + value_prefix + value + value_suffix
    }
  }
}

///|
/// `d3.format(specifier)` with the en-US locale used by Vega.
pub fn format(specifier : String) -> ((Double) -> String) raise FormatError {
  new_format(parse_specifier(specifier))
}

///|
/// d3's `exponent(x)`: the decimal exponent of |x|, NaN for 0, NaN and Infinity.
fn decimal_exponent(x : Double) -> Double {
  match decimal_parts(x.abs(), 0) {
    Some((_, e)) => e.to_double()
    None => @double.not_a_number
  }
}

///|
/// `d3.formatPrefix(specifier, value)`: formats with the SI prefix of `value`.
pub fn format_prefix(
  specifier : FormatSpecifier,
  value : Double,
) -> ((Double) -> String) raise FormatError {
  let reparsed = parse_specifier(specifier.to_spec_string())
  let exp = decimal_exponent(value)
  let e = @util.js_max(-8.0, @util.js_min(8.0, (exp / 3.0).floor())) * 3.0
  let k = @util.js_pow10(-e)
  let prefix = if e.is_nan() { "" } else { si_prefixes[8 + (e / 3.0).to_int()] }
  let f = new_format(
    parse_specifier({ ..reparsed, kind: "f", }.to_spec_string()),
  )
  fn(v : Double) { f(k * v) + prefix }
}

///|
/// d3's `precisionFixed(step)`.
pub fn precision_fixed(step : Double) -> Double {
  @util.js_max(0.0, -decimal_exponent(step.abs()))
}

///|
/// d3's `precisionPrefix(step, value)`.
pub fn precision_prefix(step : Double, value : Double) -> Double {
  @util.js_max(
    0.0,
    @util.js_max(
      -8.0,
      @util.js_min(8.0, (decimal_exponent(value) / 3.0).floor()),
    ) *
    3.0 -
    decimal_exponent(step.abs()),
  )
}

///|
/// d3's `precisionRound(step, max)`.
pub fn precision_round(step : Double, max : Double) -> Double {
  let s = step.abs()
  let m = max.abs() - s
  @util.js_max(0.0, decimal_exponent(m) - decimal_exponent(s)) + 1.0
}
