// Port of the d3-time 3.1 interval machinery as inlined in vega-time and
// vega-scale (ISC license): floor / ceil / offset / range / count / every.
// https://github.com/d3/d3-time
//
// Only the UTC flavours exist because this library treats local time as UTC.

///|
/// A calendar interval. `floor_fn` rounds an instant down to the interval
/// boundary, `offset_fn` moves by an integer number of intervals.
pub struct TimeInterval {
  floor_fn : (Double) -> Double
  offset_fn : (Double, Int32) -> Double
  count_fn : ((Double, Double) -> Double)?
  field_fn : ((Double) -> Double)?
  every_fn : ((TimeInterval, Double) -> TimeInterval?)?
}

///|
fn make_interval(
  floor_fn : (Double) -> Double,
  offset_fn : (Double, Int32) -> Double,
  count_fn? : (Double, Double) -> Double,
  field_fn? : (Double) -> Double,
  every_fn? : (TimeInterval, Double) -> TimeInterval?,
) -> TimeInterval {
  { floor_fn, offset_fn, count_fn, field_fn, every_fn, }
}

///|
pub fn TimeInterval::floor(self : TimeInterval, t : Double) -> Double {
  if t.is_nan() {
    t
  } else {
    (self.floor_fn)(t)
  }
}

///|
pub fn TimeInterval::ceil(self : TimeInterval, t : Double) -> Double {
  if t.is_nan() {
    return t
  }
  let d = (self.floor_fn)(t - 1.0)
  (self.floor_fn)((self.offset_fn)(d, 1))
}

///|
pub fn TimeInterval::round(self : TimeInterval, t : Double) -> Double {
  let d0 = self.floor(t)
  let d1 = self.ceil(t)
  if t - d0 < d1 - t {
    d0
  } else {
    d1
  }
}

///|
pub fn TimeInterval::offset(
  self : TimeInterval,
  t : Double,
  step : Int32,
) -> Double {
  if t.is_nan() {
    t
  } else {
    (self.offset_fn)(t, step)
  }
}

///|
/// Every interval boundary in [ceil(start), stop), stepping `step` intervals.
pub fn TimeInterval::range(
  self : TimeInterval,
  start : Double,
  stop : Double,
  step~ : Int32 = 1,
) -> Array[Double] {
  let out : Array[Double] = []
  let mut s = self.ceil(start)
  if !(s < stop) || !(step > 0) {
    return out
  }
  let mut previous = s
  while true {
    previous = s
    out.push(previous)
    s = (self.floor_fn)((self.offset_fn)(s, step))
    if !(previous < s && s < stop) {
      break
    }
  }
  out
}

///|
/// Number of interval boundaries between two instants; None when the
/// interval has no `count`.
pub fn TimeInterval::count(
  self : TimeInterval,
  start : Double,
  end : Double,
) -> Double? {
  match self.count_fn {
    None => None
    Some(f) => Some(f((self.floor_fn)(start), (self.floor_fn)(end)).floor())
  }
}

///|
/// An interval accepting only instants for which `accept` holds.
pub fn TimeInterval::filter(
  self : TimeInterval,
  accept : (Double) -> Bool,
) -> TimeInterval {
  make_interval(
    fn(t) {
      if t.is_nan() {
        return t
      }
      let mut d = t
      while true {
        d = (self.floor_fn)(d)
        if accept(d) {
          break
        }
        d = d - 1.0
      }
      d
    },
    fn(t, step) {
      if t.is_nan() {
        return t
      }
      let mut d = t
      if step < 0 {
        for _ in 0..<-step {
          d = (self.offset_fn)(d, -1)
          while !accept(d) {
            d = (self.offset_fn)(d, -1)
          }
        }
      } else {
        for _ in 0..<step {
          d = (self.offset_fn)(d, 1)
          while !accept(d) {
            d = (self.offset_fn)(d, 1)
          }
        }
      }
      d
    },
  )
}

///|
/// d3's `interval.every(step)`: every `step`-th boundary, or None when the
/// step is invalid or the interval cannot be subdivided.
pub fn TimeInterval::every(
  self : TimeInterval,
  step0 : Double,
) -> TimeInterval? {
  match self.every_fn {
    Some(f) => f(self, step0)
    None => {
      let step = step0.floor()
      if step.is_nan() || step.is_inf() || !(step > 0.0) {
        None
      } else if !(step > 1.0) {
        Some(self)
      } else {
        match self.field_fn {
          Some(field) => Some(self.filter(fn(d) { field(d).mod(step) == 0.0 }))
          None =>
            Some(
              self.filter(fn(d) {
                match self.count(0.0, d) {
                  Some(c) => c.mod(step) == 0.0
                  None => false
                }
              }),
            )
        }
      }
    }
  }
}

///|
fn floor_to(t : Double, unit : Double) -> Double {
  t - fl_mod(t, unit)
}

///|
fn fixed_interval(unit : Double, field_fn : (Double) -> Double) -> TimeInterval {
  make_interval(
    fn(t) { floor_to(t, unit) },
    fn(t, step) { t + step.to_double() * unit },
    count_fn=fn(a, b) { (b - a) / unit },
    field_fn~,
  )
}

///|
pub let utc_millisecond : TimeInterval = make_interval(
  fn(t) { t },
  fn(t, step) { t + step.to_double() },
  count_fn=fn(a, b) { b - a },
  every_fn=fn(self, k0) {
    let k = k0.floor()
    if k.is_nan() || k.is_inf() || !(k > 0.0) {
      None
    } else if !(k > 1.0) {
      Some(self)
    } else {
      Some(
        make_interval(
          fn(t) { (t / k).floor() * k },
          fn(t, step) { t + step.to_double() * k },
          count_fn=fn(a, b) { (b - a) / k },
        ),
      )
    }
  },
)

///|
pub let utc_second : TimeInterval = fixed_interval(ms_per_second, fn(t) {
  utc_parts(t).seconds.to_double()
})

///|
pub let utc_minute : TimeInterval = fixed_interval(ms_per_minute, fn(t) {
  utc_parts(t).minutes.to_double()
})

///|
pub let utc_hour : TimeInterval = fixed_interval(ms_per_hour, fn(t) {
  utc_parts(t).hours.to_double()
})

///|
pub let utc_day : TimeInterval = fixed_interval(ms_per_day, fn(t) {
  (utc_parts(t).date - 1).to_double()
})

///|
/// Day interval whose `every` counts days since the epoch (used by time ticks).
pub let unix_day : TimeInterval = fixed_interval(ms_per_day, fn(t) {
  fl_div(t, ms_per_day)
})

///|
/// Weeks starting on `weekday` (0 = Sunday ... 6 = Saturday).
pub fn utc_weekday(weekday : Int32) -> TimeInterval {
  make_interval(
    fn(t) {
      let day = fl_mod(fl_div(t, ms_per_day) + 4.0, 7.0)
      floor_to(t, ms_per_day) -
      fl_mod(day + 7.0 - weekday.to_double(), 7.0) * ms_per_day
    },
    fn(t, step) { t + step.to_double() * 7.0 * ms_per_day },
    count_fn=fn(a, b) { (b - a) / ms_per_week },
  )
}

///|
pub let utc_sunday : TimeInterval = utc_weekday(0)

///|
pub let utc_monday : TimeInterval = utc_weekday(1)

///|
pub let utc_thursday : TimeInterval = utc_weekday(4)

///|
pub let utc_month : TimeInterval = make_interval(
  fn(t) {
    let p = utc_parts(t)
    from_parts(p.year, p.month, 1, 0, 0, 0, 0)
  },
  fn(t, step) {
    let p = utc_parts(t)
    from_parts(
      p.year,
      p.month + step,
      p.date,
      p.hours,
      p.minutes,
      p.seconds,
      p.millis,
    )
  },
  count_fn=fn(a, b) {
    let pa = utc_parts(a)
    let pb = utc_parts(b)
    (pb.month - pa.month + (pb.year - pa.year) * 12).to_double()
  },
  field_fn=fn(t) { utc_parts(t).month.to_double() },
)

///|
pub let utc_year : TimeInterval = make_interval(
  fn(t) {
    let p = utc_parts(t)
    from_parts(p.year, 0, 1, 0, 0, 0, 0)
  },
  fn(t, step) {
    let p = utc_parts(t)
    from_parts(
      p.year + step,
      p.month,
      p.date,
      p.hours,
      p.minutes,
      p.seconds,
      p.millis,
    )
  },
  count_fn=fn(a, b) { (utc_parts(b).year - utc_parts(a).year).to_double() },
  field_fn=fn(t) { utc_parts(t).year.to_double() },
  every_fn=fn(_, k0) {
    let k = k0.floor()
    if k.is_nan() || k.is_inf() || !(k > 0.0) {
      None
    } else {
      Some(
        make_interval(
          fn(t) {
            let p = utc_parts(t)
            from_parts(
              ((p.year.to_double() / k).floor() * k).to_int(),
              0,
              1,
              0,
              0,
              0,
              0,
            )
          },
          fn(t, step) {
            let p = utc_parts(t)
            from_parts(
              p.year + (step.to_double() * k).to_int(),
              p.month,
              p.date,
              p.hours,
              p.minutes,
              p.seconds,
              p.millis,
            )
          },
        ),
      )
    }
  },
)

///|
/// vega-time's `utcInterval(unit)` for the time units that have one.
pub fn utc_interval(unit : String) -> TimeInterval? {
  match unit {
    "year" => Some(utc_year)
    "quarter" => utc_month.every(3.0)
    "month" => Some(utc_month)
    "week" => Some(utc_sunday)
    "date" | "day" | "dayofyear" => Some(utc_day)
    "hours" => Some(utc_hour)
    "minutes" => Some(utc_minute)
    "seconds" => Some(utc_second)
    "milliseconds" => Some(utc_millisecond)
    _ => None
  }
}
