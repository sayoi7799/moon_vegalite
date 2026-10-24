// Port of d3-array 3.2.4 `ticks`, `tickIncrement` and `tickStep` (ISC license).
// https://github.com/d3/d3-array/blob/v3.2.4/src/ticks.js

///|
let e10 : Double = 50.0.sqrt()

///|
let e5 : Double = 10.0.sqrt()

///|
let e2 : Double = 2.0.sqrt()

///|
/// Returns (i1, i2, inc): the first and last tick index and the increment. A
/// negative `inc` means the real increment is `1 / -inc`.
fn tick_spec(
  start : Double,
  stop : Double,
  count : Double,
) -> (Double, Double, Double) {
  let step = (stop - start) / @util.js_max(0.0, count)
  let power = @util.js_log10(step).floor()
  let error = step / @util.js_pow10(power)
  let factor = if error >= e10 {
    10.0
  } else if error >= e5 {
    5.0
  } else if error >= e2 {
    2.0
  } else {
    1.0
  }
  let mut i1 = 0.0
  let mut i2 = 0.0
  let mut inc = 0.0
  if power < 0.0 {
    inc = @util.js_pow10(-power) / factor
    i1 = @util.js_round(start * inc)
    i2 = @util.js_round(stop * inc)
    if i1 / inc < start {
      i1 = i1 + 1.0
    }
    if i2 / inc > stop {
      i2 = i2 - 1.0
    }
    inc = -inc
  } else {
    inc = @util.js_pow10(power) * factor
    i1 = @util.js_round(start / inc)
    i2 = @util.js_round(stop / inc)
    if i1 * inc < start {
      i1 = i1 + 1.0
    }
    if i2 * inc > stop {
      i2 = i2 - 1.0
    }
  }
  if i2 < i1 && 0.5 <= count && count < 2.0 {
    return tick_spec(start, stop, count * 2.0)
  }
  (i1, i2, inc)
}

///|
/// Approximately `count` evenly spaced "nice" values covering [start, stop]
/// (d3.ticks). Descending when `stop < start`.
pub fn ticks(start : Double, stop : Double, count : Double) -> Array[Double] {
  if !(count > 0.0) {
    return []
  }
  if start == stop {
    return [start]
  }
  let reverse = stop < start
  let (i1, i2, inc) = if reverse {
    tick_spec(stop, start, count)
  } else {
    tick_spec(start, stop, count)
  }
  if !(i2 >= i1) {
    return []
  }
  let n = (i2 - i1).to_int() + 1
  let out = Array::make(n, 0.0)
  if reverse {
    if inc < 0.0 {
      for i in 0..<n {
        out[i] = (i2 - i.to_double()) / -inc
      }
    } else {
      for i in 0..<n {
        out[i] = (i2 - i.to_double()) * inc
      }
    }
  } else if inc < 0.0 {
    for i in 0..<n {
      out[i] = (i1 + i.to_double()) / -inc
    }
  } else {
    for i in 0..<n {
      out[i] = (i1 + i.to_double()) * inc
    }
  }
  out
}

///|
/// d3.tickIncrement: positive for step >= 1, negative `-k` for step `1/k`.
pub fn tick_increment(start : Double, stop : Double, count : Double) -> Double {
  let (_, _, inc) = tick_spec(start, stop, count)
  inc
}

///|
/// d3.tickStep: the (signed) step between ticks.
pub fn tick_step(start : Double, stop : Double, count : Double) -> Double {
  let reverse = stop < start
  let inc = if reverse {
    tick_increment(stop, start, count)
  } else {
    tick_increment(start, stop, count)
  }
  (if reverse { -1.0 } else { 1.0 }) *
  (if inc < 0.0 { 1.0 / -inc } else { inc })
}
