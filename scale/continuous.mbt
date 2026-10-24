// Continuous scales: port of d3-scale 4 `continuous`, `linearish`, `loggish`
// and `powish` as inlined in vega-scale 7.4.3 (ISC license).
// https://github.com/d3/d3-scale

///|
pub(all) enum ScaleKind {
  Linear
  /// `Pow(exponent)`; exponent 0.5 behaves as `sqrt`
  Pow(Double)
  /// `Log(base)`
  Log(Double)
}

///|
pub fn ScaleKind::sqrt() -> ScaleKind {
  Pow(0.5)
}

///|
let math_e : Double = 2.718281828459045

///|
pub(all) struct Continuous {
  kind : ScaleKind
  mut domain : Array[Double]
  mut range : Array[Double]
  mut clamp : Bool
  /// `rangeRound`: interpolate with rounding
  mut round : Bool
}

///|
pub fn Continuous::new(kind : ScaleKind) -> Continuous {
  {
    kind,
    domain: match kind {
      Log(_) => [1.0, 10.0]
      _ => [0.0, 1.0]
    },
    range: [0.0, 1.0],
    clamp: false,
    round: false,
  }
}

///|
fn pow_transform(x : Double, exponent : Double) -> Double {
  if exponent == 1.0 {
    x
  } else if exponent == 0.5 {
    if x < 0.0 {
      -(-x).sqrt()
    } else {
      x.sqrt()
    }
  } else if x < 0.0 {
    -@math.pow(-x, exponent)
  } else {
    @math.pow(x, exponent)
  }
}

///|
/// The forward transform of the scale (identity, pow or natural log).
fn Continuous::transform(self : Continuous, x : Double) -> Double {
  match self.kind {
    Linear => x
    Pow(e) => pow_transform(x, e)
    Log(_) =>
      if self.domain.length() > 0 && self.domain[0] < 0.0 {
        -@util.js_log(-x)
      } else {
        @util.js_log(x)
      }
  }
}

///|
fn normalize(a : Double, b0 : Double) -> (Double) -> Double {
  let b = b0 - a
  if b != 0.0 {
    fn(x) { (x - a) / b }
  } else {
    let c = if b.is_nan() { @double.not_a_number } else { 0.5 }
    fn(_) { c }
  }
}

///|
fn interpolate_number(
  a : Double,
  b : Double,
  round : Bool,
) -> (Double) -> Double {
  if round {
    fn(t) { @util.js_round(a * (1.0 - t) + b * t) }
  } else {
    fn(t) { a * (1.0 - t) + b * t }
  }
}

///|
/// `bisectRight(a, x, lo, hi)` for an ascending array.
fn bisect_right(
  a : Array[Double],
  x : Double,
  lo0 : Int32,
  hi0 : Int32,
) -> Int32 {
  let mut lo = lo0
  let mut hi = hi0
  while lo < hi {
    let mid = (lo + hi) >> 1
    if a[mid] > x {
      hi = mid
    } else {
      lo = mid + 1
    }
  }
  lo
}

///|
/// Map a domain value to the range; None for NaN input (d3's `unknown`).
pub fn Continuous::map(self : Continuous, x : Double) -> Double? {
  if x.is_nan() {
    return None
  }
  let n = if self.domain.length() < self.range.length() {
    self.domain.length()
  } else {
    self.range.length()
  }
  if n < 2 {
    return Some(@double.not_a_number)
  }
  let cx = if self.clamp {
    let mut a = self.domain[0]
    let mut b = self.domain[n - 1]
    if a > b {
      let t = a
      a = b
      b = t
    }
    @util.js_max(a, @util.js_min(b, x))
  } else {
    x
  }
  let t = self.transform(cx)
  let td = self.domain.map(fn(d) { self.transform(d) })
  if n > 2 {
    // polymap
    let j = n - 1
    let mut domain = td
    let mut range = self.range
    if domain[j] < domain[0] {
      domain = domain.copy()
      domain.rev_in_place()
      range = range.copy()
      range.rev_in_place()
    }
    let i = bisect_right(domain, t, 1, j) - 1
    let norm = normalize(domain[i], domain[i + 1])
    let interp = interpolate_number(range[i], range[i + 1], self.round)
    Some(interp(norm(t)))
  } else {
    // bimap
    let d0 = td[0]
    let d1 = td[1]
    let r0 = self.range[0]
    let r1 = self.range[1]
    if d1 < d0 {
      Some(interpolate_number(r1, r0, self.round)(normalize(d1, d0)(t)))
    } else {
      Some(interpolate_number(r0, r1, self.round)(normalize(d0, d1)(t)))
    }
  }
}

// ---- logarithmic helpers ----

///|
fn pow10_text(x : Double) -> Double {
  // d3: isFinite(x) ? +("1e" + x) : x < 0 ? 0 : x
  if x.is_nan() {
    return x
  }
  if x.is_inf() {
    return if x < 0.0 { 0.0 } else { x }
  }
  if x != x.trunc() || x.abs() >= 1.0e21 {
    // "1e1.5" and "1e1e+21" are not numbers in JavaScript
    return @double.not_a_number
  }
  let text = "1e" + @util.js_number_to_string(x)
  @string.from_str(text) catch {
    _ => if x < 0.0 { 0.0 } else { @double.infinity }
  }
}

///|
fn Continuous::base(self : Continuous) -> Double {
  match self.kind {
    Log(b) => b
    _ => 10.0
  }
}

///|
fn Continuous::reflected(self : Continuous) -> Bool {
  self.domain.length() > 0 && self.domain[0] < 0.0
}

///|
fn Continuous::logs(self : Continuous, x : Double) -> Double {
  let base = self.base()
  let f = fn(v : Double) {
    if base == math_e {
      @util.js_log(v)
    } else if base == 10.0 {
      @util.js_log10(v)
    } else if base == 2.0 {
      @math.log2(v)
    } else {
      @util.js_log(v) / @util.js_log(base)
    }
  }
  if self.reflected() {
    -f(-x)
  } else {
    f(x)
  }
}

///|
fn Continuous::pows(self : Continuous, x : Double) -> Double {
  let base = self.base()
  let f = fn(v : Double) {
    if base == 10.0 {
      pow10_text(v)
    } else if base == math_e {
      @math.exp(v)
    } else {
      @math.pow(base, v)
    }
  }
  if self.reflected() {
    -f(-x)
  } else {
    f(x)
  }
}

///|
fn Continuous::log_ticks(self : Continuous, count : Double) -> Array[Double] {
  let d = self.domain
  let mut u = d[0]
  let mut v = d[d.length() - 1]
  let r = v < u
  if r {
    let t = u
    u = v
    v = t
  }
  let base = self.base()
  let mut i = self.logs(u)
  let mut j = self.logs(v)
  let n = count
  let mut z : Array[Double] = []
  if base.mod(1.0) == 0.0 && j - i < n {
    i = i.floor()
    j = j.ceil()
    if u > 0.0 {
      while i <= j {
        let mut k = 1.0
        while k < base {
          let t = if i < 0.0 { k / self.pows(-i) } else { k * self.pows(i) }
          if t < u {
            k = k + 1.0
            continue
          }
          if t > v {
            break
          }
          z.push(t)
          k = k + 1.0
        }
        i = i + 1.0
      }
    } else {
      while i <= j {
        let mut k = base - 1.0
        while k >= 1.0 {
          let t = if i > 0.0 { k / self.pows(-i) } else { k * self.pows(i) }
          if t < u {
            k = k - 1.0
            continue
          }
          if t > v {
            break
          }
          z.push(t)
          k = k - 1.0
        }
        i = i + 1.0
      }
    }
    if z.length().to_double() * 2.0 < n {
      z = @stats.ticks(u, v, n)
    }
  } else {
    z = @stats.ticks(i, j, @util.js_min(j - i, n)).map(fn(x) { self.pows(x) })
  }
  if r {
    z.rev_in_place()
  }
  z
}

///|
/// Approximately `count` nice tick values (d3 `scale.ticks`).
pub fn Continuous::ticks(
  self : Continuous,
  count~ : Double = 10.0,
) -> Array[Double] {
  match self.kind {
    Log(_) => self.log_ticks(count)
    _ =>
      @stats.ticks(self.domain[0], self.domain[self.domain.length() - 1], count)
  }
}

///|
/// d3 `scale.nice(count)`: widen the domain to round values.
pub fn Continuous::nice(self : Continuous, count~ : Double = 10.0) -> Unit {
  match self.kind {
    Log(_) => {
      let d = self.domain.copy()
      let mut i0 = 0
      let mut i1 = d.length() - 1
      let mut x0 = d[i0]
      let mut x1 = d[i1]
      if x1 < x0 {
        let t = i0
        i0 = i1
        i1 = t
        let tx = x0
        x0 = x1
        x1 = tx
      }
      d[i0] = self.pows(self.logs(x0).floor())
      d[i1] = self.pows(self.logs(x1).ceil())
      self.domain = d
    }
    _ => {
      let d = self.domain.copy()
      let mut i0 = 0
      let mut i1 = d.length() - 1
      let mut start = d[i0]
      let mut stop = d[i1]
      let mut prestep = @double.not_a_number
      let mut have_prestep = false
      if stop < start {
        let t = start
        start = stop
        stop = t
        let ti = i0
        i0 = i1
        i1 = ti
      }
      let mut iter = 10
      while iter > 0 {
        iter = iter - 1
        let step = @stats.tick_increment(start, stop, count)
        if have_prestep && step == prestep {
          d[i0] = start
          d[i1] = stop
          self.domain = d
          return
        } else if step > 0.0 {
          start = (start / step).floor() * step
          stop = (stop / step).ceil() * step
        } else if step < 0.0 {
          start = (start * step).ceil() / step
          stop = (stop * step).floor() / step
        } else {
          break
        }
        prestep = step
        have_prestep = true
      }
    }
  }
}
