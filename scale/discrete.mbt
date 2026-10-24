// Discrete scales: band and point (vega-scale 7.4.3 `scaleBand`, BSD-3-Clause)
// and ordinal (d3-scale 4 `ordinal`, ISC), plus the sequential colour scale.

///|
/// A key identifying a domain value the way d3's `InternMap` does: values of
/// different types never collide (the number 1 and the string "1" differ).
pub fn value_key(v : @value.Value) -> String {
  match v {
    Null => "z:"
    Bool(b) => "b:" + (if b { "1" } else { "0" })
    Num(x) => "n:" + @util.js_number_to_string(x)
    Str(s) => "s:" + s
    other => "o:" + other.to_js_string()
  }
}

///|
/// vega-scale's `bandSpace(count, paddingInner, paddingOuter)`.
pub fn band_space(
  count : Double,
  padding_inner : Double,
  padding_outer : Double,
) -> Double {
  let space = count - padding_inner + padding_outer * 2.0
  if count != 0.0 {
    if space > 0.0 {
      space
    } else {
      1.0
    }
  } else {
    0.0
  }
}

///|
fn clamp01(x : Double) -> Double {
  @util.js_max(0.0, @util.js_min(1.0, x))
}

///|
/// Band and point scales. A point scale is a band scale with an inner padding
/// of 1 whose `padding` only changes the outer padding.
pub struct Band {
  is_point : Bool
  mut keys : Array[String]
  mut range : (Double, Double)
  mut padding_inner : Double
  mut padding_outer : Double
  mut align : Double
  mut round : Bool
  mut step : Double
  mut bandwidth : Double
  mut positions : Array[Double]
}

///|
fn Band::make(is_point : Bool) -> Band {
  let b : Band = {
    is_point,
    keys: [],
    range: (0.0, 1.0),
    padding_inner: if is_point {
      1.0
    } else {
      0.0
    },
    padding_outer: 0.0,
    align: 0.5,
    round: false,
    step: 0.0,
    bandwidth: 0.0,
    positions: [],
  }
  b.rescale()
  b
}

///|
pub fn Band::band() -> Band {
  Band::make(false)
}

///|
pub fn Band::point() -> Band {
  Band::make(true)
}

///|
fn Band::rescale(self : Band) -> Unit {
  let n = self.keys.length().to_double()
  let (r0, r1) = self.range
  let reverse = r1 < r0
  let stop = if reverse { r0 } else { r1 }
  let mut start = if reverse { r1 } else { r0 }
  let space = band_space(n, self.padding_inner, self.padding_outer)
  self.step = (stop - start) / (if space != 0.0 { space } else { 1.0 })
  if self.round {
    self.step = self.step.floor()
  }
  start = start +
    (stop - start - self.step * (n - self.padding_inner)) * self.align
  self.bandwidth = self.step * (1.0 - self.padding_inner)
  if self.round {
    start = @util.js_round(start)
    self.bandwidth = @util.js_round(self.bandwidth)
  }
  let values : Array[Double] = []
  for i in 0..<self.keys.length() {
    values.push(start + self.step * i.to_double())
  }
  if reverse {
    values.rev_in_place()
  }
  self.positions = values
}

///|
/// Set the domain (duplicates are ignored, first occurrence wins).
pub fn Band::set_domain(self : Band, values : Array[@value.Value]) -> Unit {
  let keys : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for v in values {
    let k = value_key(v)
    if !seen.contains(k) {
      seen[k] = true
      keys.push(k)
    }
  }
  self.keys = keys
  self.rescale()
}

///|
pub fn Band::set_range(self : Band, r0 : Double, r1 : Double) -> Unit {
  self.range = (r0, r1)
  self.rescale()
}

///|
/// `rangeRound`: set the range and round positions and sizes to integers.
pub fn Band::set_range_round(self : Band, r0 : Double, r1 : Double) -> Unit {
  self.range = (r0, r1)
  self.round = true
  self.rescale()
}

///|
pub fn Band::set_round(self : Band, round : Bool) -> Unit {
  self.round = round
  self.rescale()
}

///|
pub fn Band::set_padding(self : Band, p : Double) -> Unit {
  self.padding_outer = clamp01(p)
  if !self.is_point {
    self.padding_inner = self.padding_outer
  }
  self.rescale()
}

///|
pub fn Band::set_padding_inner(self : Band, p : Double) -> Unit {
  self.padding_inner = clamp01(p)
  self.rescale()
}

///|
pub fn Band::set_padding_outer(self : Band, p : Double) -> Unit {
  self.padding_outer = clamp01(p)
  self.rescale()
}

///|
pub fn Band::set_align(self : Band, a : Double) -> Unit {
  self.align = clamp01(a)
  self.rescale()
}

///|
/// Start position of the band for a domain value, None if not in the domain.
pub fn Band::map(self : Band, v : @value.Value) -> Double? {
  let k = value_key(v)
  for i in 0..<self.keys.length() {
    if self.keys[i] == k {
      return Some(self.positions[i])
    }
  }
  None
}

// ---- ordinal ----

///|
/// An ordinal scale: domain values are matched by `value_key` and the range
/// repeats when it is shorter than the domain.
pub struct Ordinal {
  mut keys : Array[String]
  mut range : Array[@value.Value]
}

///|
pub fn Ordinal::new() -> Ordinal {
  { keys: [], range: [], }
}

///|
pub fn Ordinal::set_domain(
  self : Ordinal,
  values : Array[@value.Value],
) -> Unit {
  let keys : Array[String] = []
  for v in values {
    let k = value_key(v)
    if !keys.contains(k) {
      keys.push(k)
    }
  }
  self.keys = keys
}

///|
pub fn Ordinal::set_range(self : Ordinal, range : Array[@value.Value]) -> Unit {
  self.range = range
}

///|
/// The range value for a domain value; None if unknown (or the range is empty).
pub fn Ordinal::map(self : Ordinal, v : @value.Value) -> @value.Value? {
  let k = value_key(v)
  for i in 0..<self.keys.length() {
    if self.keys[i] == k {
      if self.range.length() == 0 {
        return None
      }
      return Some(self.range[i % self.range.length()])
    }
  }
  None
}

// ---- sequential colour ----

///|
/// A sequential colour scale: a continuous domain mapped to [0, 1] and then
/// through a colour interpolator (d3 `scaleSequential`).
pub(all) struct Sequential {
  scale : Continuous
  mut interpolator : (Double) -> String
}

///|
pub fn Sequential::new(
  kind : ScaleKind,
  interpolator : (Double) -> String,
) -> Sequential {
  { scale: Continuous::new(kind), interpolator, }
}

///|
pub fn Sequential::map(self : Sequential, x : Double) -> String? {
  if x.is_nan() {
    return None
  }
  let d = self.scale.domain
  let t0 = self.scale.transform(d[0])
  let t1 = self.scale.transform(d[d.length() - 1])
  let k10 = if t0 == t1 { 0.0 } else { 1.0 / (t1 - t0) }
  if k10 == 0.0 {
    return Some((self.interpolator)(0.5))
  }
  let v = (self.scale.transform(x) - t0) * k10
  Some((self.interpolator)(if self.scale.clamp { clamp01(v) } else { v }))
}
