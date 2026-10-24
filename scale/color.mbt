// Colours: parsing (d3-color 3.1), RGB interpolation and piecewise
// interpolators (d3-interpolate 3.0), as inlined in vega-scale (ISC license).

///|
/// An sRGB colour with fractional channels, as d3-color's `Rgb`.
pub struct Rgb {
  r : Double
  g : Double
  b : Double
  opacity : Double
}

///|
fn clampi(v : Double) -> Double {
  // Math.max(0, Math.min(255, Math.round(value) || 0))
  let r = @util.js_round(v)
  let r2 = if r.is_nan() || r == 0.0 { 0.0 } else { r }
  @util.js_max(0.0, @util.js_min(255.0, r2))
}

///|
fn clampa(opacity : Double) -> Double {
  if opacity.is_nan() {
    1.0
  } else {
    @util.js_max(0.0, @util.js_min(1.0, opacity))
  }
}

///|
/// `rgb(r, g, b)` (or `rgba(r, g, b, a)`), channels rounded and clamped, as
/// d3-color's `formatRgb`.
pub fn Rgb::format_rgb(self : Rgb) -> String {
  let a = clampa(self.opacity)
  let ch = fn(v : Double) { @util.js_number_to_string(clampi(v)) }
  if a == 1.0 {
    "rgb(" + ch(self.r) + ", " + ch(self.g) + ", " + ch(self.b) + ")"
  } else {
    "rgba(" +
    ch(self.r) +
    ", " +
    ch(self.g) +
    ", " +
    ch(self.b) +
    ", " +
    @util.js_number_to_string(a) +
    ")"
  }
}

///|
fn hex_digit(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else {
    -1
  }
}

///|
fn rgb_of_int(n : Int32) -> Rgb {
  {
    r: ((n >> 16) & 0xff).to_double(),
    g: ((n >> 8) & 0xff).to_double(),
    b: (n & 0xff).to_double(),
    opacity: 1.0,
  }
}

///|
/// Parse a CSS colour: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb(r, g, b)`,
/// `rgba(r, g, b, a)` (integers or percentages) and the CSS colour keywords.
pub fn parse_color(text : String) -> Rgb? {
  let s = text.trim().to_owned().to_lower()
  if s.has_prefix("#") {
    let cs = s.to_array()
    let n = cs.length() - 1
    let mut v = 0
    for i in 1..<cs.length() {
      let d = hex_digit(cs[i])
      if d < 0 {
        return None
      }
      v = v * 16 + d
    }
    return match n {
      6 => Some(rgb_of_int(v))
      3 =>
        Some({
          r: (((v >> 8) & 0xf) * 17).to_double(),
          g: (((v >> 4) & 0xf) * 17).to_double(),
          b: ((v & 0xf) * 17).to_double(),
          opacity: 1.0,
        })
      8 =>
        Some({
          r: ((v >> 24) & 0xff).to_double(),
          g: ((v >> 16) & 0xff).to_double(),
          b: ((v >> 8) & 0xff).to_double(),
          opacity: (v & 0xff).to_double() / 255.0,
        })
      4 =>
        Some({
          r: (((v >> 12) & 0xf) * 17).to_double(),
          g: (((v >> 8) & 0xf) * 17).to_double(),
          b: (((v >> 4) & 0xf) * 17).to_double(),
          opacity: ((v & 0xf) * 17).to_double() / 255.0,
        })
      _ => None
    }
  }
  if s.has_prefix("rgb(") || s.has_prefix("rgba(") {
    return parse_rgb_function(s)
  }
  if s == "transparent" {
    return Some({
      r: @double.not_a_number,
      g: @double.not_a_number,
      b: @double.not_a_number,
      opacity: 0.0,
    })
  }
  match named_color(s) {
    Some(n) => Some(rgb_of_int(n))
    None => None
  }
}

///|
fn parse_rgb_function(s : String) -> Rgb? {
  let open = s.find("(").unwrap_or(0)
  if !s.has_suffix(")") {
    return None
  }
  let inner = s.unsafe_substring(start=open + 1, end=s.length() - 1)
  let parts : Array[String] = inner
    .split(",")
    .map(fn(p) { p.trim().to_owned() })
    .collect()
  let has_alpha = s.has_prefix("rgba(")
  if parts.length() != (if has_alpha { 4 } else { 3 }) {
    return None
  }
  let chans : Array[Double] = []
  let mut percent = false
  for i in 0..<3 {
    let p = parts[i]
    if p.has_suffix("%") {
      percent = true
      let v = @value.string_to_number(
        p.unsafe_substring(start=0, end=p.length() - 1),
      )
      if v.is_nan() {
        return None
      }
      chans.push(v * 255.0 / 100.0)
    } else {
      let v = @value.string_to_number(p)
      if v.is_nan() {
        return None
      }
      chans.push(v)
    }
  }
  ignore(percent)
  let a = if has_alpha {
    let v = @value.string_to_number(parts[3])
    if v.is_nan() {
      return None
    }
    v
  } else {
    1.0
  }
  Some({ r: chans[0], g: chans[1], b: chans[2], opacity: a, })
}

///|
fn lerp_channel(a : Double, b : Double) -> (Double) -> Double {
  let d = b - a
  if d != 0.0 {
    fn(t) { a + t * d }
  } else {
    let c = if a.is_nan() { b } else { a }
    fn(_) { c }
  }
}

///|
/// d3's `interpolateRgb(a, b)` (gamma 1): a function from t in [0, 1] to
/// an `rgb(...)` string. Unparsable colours interpolate as NaN channels.
pub fn interpolate_rgb(a : String, b : String) -> (Double) -> String {
  let nan = @double.not_a_number
  let ca = parse_color(a).unwrap_or({ r: nan, g: nan, b: nan, opacity: 1.0, })
  let cb = parse_color(b).unwrap_or({ r: nan, g: nan, b: nan, opacity: 1.0, })
  let r = lerp_channel(ca.r, cb.r)
  let g = lerp_channel(ca.g, cb.g)
  let bl = lerp_channel(ca.b, cb.b)
  let o = lerp_channel(ca.opacity, cb.opacity)
  fn(t) { { r: r(t), g: g(t), b: bl(t), opacity: o(t), }.format_rgb() }
}

///|
/// d3's `piecewise(interpolateRgb, colors)` as built by vega-scale's
/// `interpolateColors`: spreads the colours evenly over t in [0, 1].
pub fn interpolate_colors(colors : Array[String]) -> (Double) -> String {
  let n = colors.length() - 1
  let pieces : Array[(Double) -> String] = []
  for i in 0..<n {
    pieces.push(interpolate_rgb(colors[i], colors[i + 1]))
  }
  fn(t0) {
    let t = t0 * n.to_double()
    let i = @util.js_max(0.0, @util.js_min((n - 1).to_double(), t.floor())).to_int()
    pieces[i](t - i.to_double())
  }
}

///|
/// vega-scale's `quantizeInterpolator(interpolator, count)`.
pub fn quantize_interpolator(
  interpolator : (Double) -> String,
  count : Int32,
) -> Array[String] {
  let out : Array[String] = []
  let n = (count + 1).to_double()
  for i in 0..<count {
    out.push(interpolator((i + 1).to_double() / n))
  }
  out
}

///|
/// vega-scale's `interpolateRange(interpolator, [lo, hi])`: restricts an
/// interpolator to a sub-range of [0, 1] (reversed when lo > hi).
pub fn interpolate_range(
  interpolator : (Double) -> String,
  lo : Double,
  hi : Double,
) -> (Double) -> String {
  let span = hi - lo
  fn(i) { interpolator(lo + i * span) }
}
