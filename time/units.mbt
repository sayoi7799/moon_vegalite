// Port of vega-time's time units and `utcFloor` (BSD-3-Clause).
// https://github.com/vega/vega/blob/v5.33.1/packages/vega-time/src/floor.js

///|
pub(all) suberror TimeError {
  TimeError(String)
}

///|
let time_unit_names : Array[String] = [
  "year", "quarter", "month", "week", "date", "day", "dayofyear", "hours", "minutes",
  "seconds", "milliseconds",
]

///|
fn unit_rank(u : String) -> Int32? {
  for i in 0..<time_unit_names.length() {
    if time_unit_names[i] == u {
      return Some(i + 1)
    }
  }
  None
}

///|
/// vega-time's `timeUnits`: validates a list of unit names and sorts it into
/// canonical order (year first, milliseconds last).
pub fn time_units(units : Array[String]) -> Array[String] raise TimeError {
  if units.length() == 0 {
    raise TimeError("Missing time unit.")
  }
  let has = fn(name : String) { units.contains(name) }
  for u in units {
    if unit_rank(u) is None {
      raise TimeError("Invalid time unit: \{u}.")
    }
  }
  let num_types = (if has("week") || has("day") { 1 } else { 0 }) +
    (if has("quarter") || has("month") || has("date") { 1 } else { 0 }) +
    (if has("dayofyear") { 1 } else { 0 })
  if num_types > 1 {
    raise TimeError("Incompatible time units: " + units.join(","))
  }
  let sorted = units.copy()
  sorted.sort_by_key(fn(u) { unit_rank(u).unwrap_or(0) })
  sorted
}

///|
/// Day of the week of January 1st of `year` (0 = Sunday).
fn utc_first(year : Int32) -> Int32 {
  utc_parts(from_parts(year, 0, 1, 0, 0, 0, 0)).day
}

///|
fn weekday_offset(week : Int32, day : Int32, first_day : Int32) -> Int32 {
  day + week * 7 - (first_day + 6) % 7
}

///|
fn year_start(t : Double) -> Double {
  from_parts(utc_parts(t).year, 0, 1, 0, 0, 0, 0)
}

///|
/// A per-unit extractor `(instant, output year) -> value`.
fn unit_getter(key : String) -> (Double, Int32) -> Int32 {
  match key {
    "year" => fn(t, _) { utc_parts(t).year }
    "quarter" => fn(t, _) { utc_parts(t).month / 3 }
    "month" => fn(t, _) { utc_parts(t).month }
    "date" => fn(t, _) { utc_parts(t).date }
    "hours" => fn(t, _) { utc_parts(t).hours }
    "minutes" => fn(t, _) { utc_parts(t).minutes }
    "seconds" => fn(t, _) { utc_parts(t).seconds }
    "milliseconds" => fn(t, _) { utc_parts(t).millis }
    "dayofyear" => fn(t, _) { count_between(utc_day, year_start(t) - 1.0, t) }
    "week" => fn(t, _) { count_between(utc_sunday, year_start(t) - 1.0, t) }
    "day" => fn(t, y) { weekday_offset(1, utc_parts(t).day, utc_first(y)) }
    _ =>
      // week + day
      fn(t, y) {
        weekday_offset(
          count_between(utc_sunday, year_start(t) - 1.0, t),
          utc_parts(t).day,
          utc_first(y),
        )
      }
  }
}

///|
fn unit_inverse(key : String) -> ((Int32, Int32) -> Int32)? {
  match key {
    "quarter" => Some(fn(q, _) { 3 * q })
    "week" => Some(fn(w, y) { weekday_offset(w, 0, utc_first(y)) })
    _ => None
  }
}

///|
/// vega-time's `getUnit`: quantize to `step` (with an optional phase), then
/// apply the inverse mapping.
fn get_unit(
  f : (Double, Int32) -> Int32,
  inv : ((Int32, Int32) -> Int32)?,
  step : Int32,
  phase : Int32,
) -> (Double, Int32) -> Int32 {
  let u : (Double, Int32) -> Int32 = if step <= 1 {
    f
  } else if phase != 0 {
    fn(t, y) {
      phase +
      step * ((f(t, y) - phase).to_double() / step.to_double()).floor().to_int()
    }
  } else {
    fn(t, y) {
      step * (f(t, y).to_double() / step.to_double()).floor().to_int()
    }
  }
  match inv {
    Some(g) => fn(t, y) { g(u(t, y), y) }
    None => u
  }
}

///|
/// vega-time's `utcFloor(units, step)`: a function rounding an instant down
/// to the given unit combination. Fields of coarser units that are not listed
/// take fixed defaults (year 2012, month 0, day 1, ...), so `["month"]` maps
/// every instant into 2012.
pub fn utc_floor(
  units : Array[String],
  step~ : Int32 = 1,
) -> ((Double) -> Double) raise TimeError {
  let u = time_units(units)
  let s = if step == 0 { 1 } else { step }
  let last = u[u.length() - 1]
  let has = fn(name : String) { u.contains(name) }
  let pick = fn(unit : String, phase : Int32, key : String) {
    get_unit(
      unit_getter(key),
      unit_inverse(key),
      if unit == last {
        s
      } else {
        0
      },
      phase,
    )
  }
  let zero : (Double, Int32) -> Int32 = fn(_, _) { 0 }
  let one : (Double, Int32) -> Int32 = fn(_, _) { 1 }
  let y : (Double, Int32) -> Int32 = if has("year") {
    pick("year", 0, "year")
  } else {
    fn(_, _) { 2012 }
  }
  let m = if has("month") {
    pick("month", 0, "month")
  } else if has("quarter") {
    pick("quarter", 0, "quarter")
  } else {
    zero
  }
  let d = if has("week") && has("day") {
    pick("day", 1, "weekday")
  } else if has("week") {
    pick("week", 1, "week")
  } else if has("day") {
    pick("day", 1, "day")
  } else if has("date") {
    pick("date", 1, "date")
  } else if has("dayofyear") {
    pick("dayofyear", 1, "dayofyear")
  } else {
    one
  }
  let hh = if has("hours") { pick("hours", 0, "hours") } else { zero }
  let mm = if has("minutes") { pick("minutes", 0, "minutes") } else { zero }
  let ss = if has("seconds") { pick("seconds", 0, "seconds") } else { zero }
  let ll = if has("milliseconds") {
    pick("milliseconds", 0, "milliseconds")
  } else {
    zero
  }
  fn(t : Double) {
    let year = y(t, 0)
    // vega-time's utcDate mishandles years 0..99 (it yields an invalid date)
    if year >= 0 && year < 100 {
      return @double.not_a_number
    }
    from_parts(
      year,
      m(t, year),
      d(t, year),
      hh(t, year),
      mm(t, year),
      ss(t, year),
      ll(t, year),
    )
  }
}
