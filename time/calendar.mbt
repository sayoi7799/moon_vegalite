// UTC calendar arithmetic with JavaScript `Date` semantics.
//
// An instant is a Double: milliseconds since 1970-01-01T00:00:00Z, NaN for an
// invalid date. This library treats "local time" as UTC (see the README), so
// every `getX` of the JavaScript originals maps to the UTC accessor here.

///|
let ms_per_second : Double = 1000.0

///|
let ms_per_minute : Double = 60000.0

///|
let ms_per_hour : Double = 3600000.0

///|
let ms_per_day : Double = 86400000.0

///|
let ms_per_week : Double = 604800000.0

///|
let max_time : Double = 8.64e15

///|
fn fl_div(a : Double, b : Double) -> Double {
  (a / b).floor()
}

///|
fn fl_mod(a : Double, b : Double) -> Double {
  a - (a / b).floor() * b
}

///|
/// Days since the epoch of a proleptic Gregorian date (Howard Hinnant's algorithm).
fn days_from_civil(y0 : Int64, m : Int32, d : Int64) -> Int64 {
  let y = if m <= 2 { y0 - 1L } else { y0 }
  let era = (if y >= 0L { y } else { y - 399L }) / 400L
  let yoe = y - era * 400L
  let mp = if m > 2 { m - 3 } else { m + 9 }
  let doy = (153L * mp.to_int64() + 2L) / 5L + d - 1L
  let doe = yoe * 365L + yoe / 4L - yoe / 100L + doy
  era * 146097L + doe - 719468L
}

///|
fn civil_from_days(z0 : Int64) -> (Int64, Int32, Int32) {
  let z = z0 + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = (doy - (153L * mp + 2L) / 5L + 1L).to_int()
  let m = if mp < 10L { (mp + 3L).to_int() } else { (mp - 9L).to_int() }
  (if m <= 2 { y + 1L } else { y }, m, d)
}

///|
/// The broken-down UTC fields of an instant (`getUTC*` of a JavaScript Date).
pub struct DateParts {
  year : Int32
  /// 0 = January
  month : Int32
  /// day of the month, 1-based
  date : Int32
  /// 0 = Sunday
  day : Int32
  hours : Int32
  minutes : Int32
  seconds : Int32
  millis : Int32
}

///|
/// Break a finite instant into UTC fields.
pub fn utc_parts(t : Double) -> DateParts {
  let days = fl_div(t, ms_per_day)
  let rem = t - days * ms_per_day
  let (y, m, d) = civil_from_days(days.to_int64())
  let hours = fl_div(rem, ms_per_hour)
  let rem1 = rem - hours * ms_per_hour
  let minutes = fl_div(rem1, ms_per_minute)
  let rem2 = rem1 - minutes * ms_per_minute
  let seconds = fl_div(rem2, ms_per_second)
  {
    year: y.to_int(),
    month: m - 1,
    date: d,
    day: fl_mod(days + 4.0, 7.0).to_int(),
    hours: hours.to_int(),
    minutes: minutes.to_int(),
    seconds: seconds.to_int(),
    millis: (rem2 - seconds * ms_per_second).to_int(),
  }
}

///|
fn to_integer(x : Double) -> Double {
  if x.is_nan() || x.is_inf() {
    @double.not_a_number
  } else {
    x.trunc()
  }
}

///|
/// `Date.UTC(year, month, date, hours, minutes, seconds, ms)`: out-of-range
/// fields carry over (month 12 is January of the next year, day 0 is the last
/// day of the previous month); years 0..99 mean 1900..1999.
pub fn utc_ms(
  year : Double,
  month : Double,
  date : Double,
  hours : Double,
  minutes : Double,
  seconds : Double,
  millis : Double,
) -> Double {
  let y0 = to_integer(year)
  let mo = to_integer(month)
  let d = to_integer(date)
  let h = to_integer(hours)
  let mi = to_integer(minutes)
  let s = to_integer(seconds)
  let l = to_integer(millis)
  if y0.is_nan() ||
    mo.is_nan() ||
    d.is_nan() ||
    h.is_nan() ||
    mi.is_nan() ||
    s.is_nan() ||
    l.is_nan() {
    return @double.not_a_number
  }
  let y = if y0 >= 0.0 && y0 <= 99.0 { 1900.0 + y0 } else { y0 }
  utc_ms_exact_year(y, mo, d, h, mi, s, l)
}

///|
/// Like `utc_ms` but without the 0..99 year mapping (JavaScript's
/// `setUTCFullYear` semantics). All arguments must be integral and finite.
pub fn utc_ms_exact_year(
  y : Double,
  mo : Double,
  d : Double,
  h : Double,
  mi : Double,
  s : Double,
  l : Double,
) -> Double {
  let ym = y * 12.0 + mo
  let yy = fl_div(ym, 12.0)
  let mm = ym - yy * 12.0
  if yy.abs() > 400000.0 {
    return @double.not_a_number
  }
  let days = days_from_civil(yy.to_int64(), mm.to_int() + 1, 1L).to_double() +
    (d - 1.0)
  let t = days * ms_per_day +
    h * ms_per_hour +
    mi * ms_per_minute +
    s * ms_per_second +
    l
  if t.abs() > max_time {
    @double.not_a_number
  } else {
    t
  }
}

///|
/// Instant of the given UTC fields (all integral); used by interval arithmetic.
fn from_parts(
  y : Int32,
  mo : Int32,
  d : Int32,
  h : Int32,
  mi : Int32,
  s : Int32,
  l : Int32,
) -> Double {
  utc_ms_exact_year(
    y.to_double(),
    mo.to_double(),
    d.to_double(),
    h.to_double(),
    mi.to_double(),
    s.to_double(),
    l.to_double(),
  )
}

///|
/// ECMAScript TimeClip: NaN outside +-8.64e15 ms, integral otherwise.
fn time_clip(t : Double) -> Double {
  if t.is_nan() || t.abs() > max_time {
    @double.not_a_number
  } else {
    t.trunc()
  }
}
