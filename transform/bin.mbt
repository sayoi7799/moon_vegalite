// vega-statistics `bin` and the vega-transforms `Bin` transform.

///|
pub(all) suberror TransformError {
  TransformError(String)
}

///|
/// Options for the binning step computation (vega-statistics `bin`).
pub(all) struct BinParams {
  extent : (Double, Double)
  maxbins : Double
  base : Double
  divide : Array[Double]
  step : Double?
  steps : Array[Double]?
  minstep : Double
  nice : Bool
  span : Double?
  anchor : Double?
}

///|
pub fn BinParams::new(
  extent : (Double, Double),
  maxbins~ : Double = 20.0,
  base~ : Double = 10.0,
  divide~ : Array[Double] = [5.0, 2.0],
  step? : Double,
  steps? : Array[Double],
  minstep~ : Double = 0.0,
  nice~ : Bool = true,
  span? : Double,
  anchor? : Double,
) -> BinParams {
  { extent, maxbins, base, divide, step, steps, minstep, nice, span, anchor, }
}

///|
/// The result of the step computation: bin boundaries start, stop and width.
pub struct Bins {
  start : Double
  stop : Double
  step : Double
}

///|
/// `Math.pow(base, e)`: exact (V8-identical) for base 10.
fn pow_base(base : Double, e : Double) -> Double {
  if base == 10.0 {
    @util.js_pow10(e)
  } else {
    @math.pow(base, e)
  }
}

///|
/// vega-statistics `bin(options)`: pick a bin width and (optionally nice) bounds.
pub fn compute_bins(p : BinParams) -> Bins {
  let maxb = p.maxbins
  let base = p.base
  let logb = @util.js_log(base)
  let mut min = p.extent.0
  let mut max = p.extent.1
  let span = match p.span {
    Some(s) if s != 0.0 && !s.is_nan() => s
    _ => {
      let d = max - min
      if d != 0.0 && !d.is_nan() {
        d
      } else if min.abs() != 0.0 && !min.is_nan() {
        min.abs()
      } else {
        1.0
      }
    }
  }
  let mut step = 0.0
  match p.step {
    Some(s) if s != 0.0 => step = s
    _ =>
      match p.steps {
        Some(steps) => {
          let v = span / maxb
          let mut i = 0
          while i < steps.length() && steps[i] < v {
            i = i + 1
          }
          step = steps[if i - 1 > 0 { i - 1 } else { 0 }]
        }
        None => {
          let level = (@util.js_log(maxb) / logb).ceil()
          let minstep = p.minstep
          step = @util.js_max(
            minstep,
            pow_base(base, @util.js_round(@util.js_log(span) / logb) - level),
          )
          while (span / step).ceil() > maxb {
            step = step * base
          }
          for d in p.divide {
            let v = step / d
            if v >= minstep && span / v <= maxb {
              step = v
            }
          }
        }
      }
  }
  let v = @util.js_log(step)
  let precision = if v >= 0.0 { 0 } else { @util.js_to_int32(-v / logb) + 1 }
  let eps = pow_base(base, -precision.to_double() - 1.0)
  if p.nice {
    let lo = (min / step + eps).floor() * step
    min = if min < lo { lo - step } else { lo }
    max = (max / step).ceil() * step
  }
  { start: min, stop: if max == min { min + step } else { max }, step, }
}

///|
/// A binning function: maps a value to the start of its bin (or -Infinity /
/// +Infinity outside the bounds, None for null).
pub struct Binner {
  start : Double
  stop : Double
  step : Double
  /// the unrounded stop returned by `compute_bins`
  raw_stop : Double
}

///|
pub fn make_binner(p : BinParams) -> Binner {
  let bins = compute_bins(p)
  let step = bins.step
  let mut start = bins.start
  let mut stop = start + ((bins.stop - start) / step).ceil() * step
  match p.anchor {
    Some(a) => {
      let d = a - (start + step * ((a - start) / step).floor())
      start = start + d
      stop = stop + d
    }
    None => ()
  }
  { start, stop, step, raw_stop: bins.stop, }
}

///|
pub fn Binner::bin(self : Binner, v : @value.Value) -> Double? {
  match v.coerce_number() {
    Num(x) => {
      let r = if x < self.start {
        @double.neg_infinity
      } else if x > self.stop {
        @double.infinity
      } else {
        let c = @util.js_max(self.start, @util.js_min(x, self.stop - self.step))
        self.start +
        self.step * (1.0e-14 + (c - self.start) / self.step).floor()
      }
      Some(r)
    }
    _ => None
  }
}

///|
/// vega `Bin` transform: writes the bin start to `as0` and (with `interval`)
/// the exclusive bin end to `as1`.
pub fn bin_rows(
  rows : Array[Map[String, @value.Value]],
  field : String,
  p : BinParams,
  as0 : String,
  as1 : String,
  interval~ : Bool = true,
) -> Unit {
  let binner = make_binner(p)
  for t in rows {
    match binner.bin(@value.get_field(t, field)) {
      Some(v) => {
        t[as0] = Num(v)
        if interval {
          t[as1] = Num(
            binner.start +
            binner.step * (1.0 + (v - binner.start) / binner.step),
          )
        }
      }
      None => {
        t[as0] = Null
        if interval {
          t[as1] = Null
        }
      }
    }
  }
}
