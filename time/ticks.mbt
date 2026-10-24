// Time-scale tick selection: d3-scale's `ticker` (UTC flavour), as inlined in
// vega-scale 7.4.3 (ISC license).

///|
let duration_month : Double = 2592000000.0

///|
let duration_year : Double = 31536000000.0

///|
fn tick_table() -> Array[(TimeInterval, Double, Double)] {
  [
    (utc_second, 1.0, ms_per_second),
    (utc_second, 5.0, 5.0 * ms_per_second),
    (utc_second, 15.0, 15.0 * ms_per_second),
    (utc_second, 30.0, 30.0 * ms_per_second),
    (utc_minute, 1.0, ms_per_minute),
    (utc_minute, 5.0, 5.0 * ms_per_minute),
    (utc_minute, 15.0, 15.0 * ms_per_minute),
    (utc_minute, 30.0, 30.0 * ms_per_minute),
    (utc_hour, 1.0, ms_per_hour),
    (utc_hour, 3.0, 3.0 * ms_per_hour),
    (utc_hour, 6.0, 6.0 * ms_per_hour),
    (utc_hour, 12.0, 12.0 * ms_per_hour),
    (unix_day, 1.0, ms_per_day),
    (unix_day, 2.0, 2.0 * ms_per_day),
    (utc_sunday, 1.0, ms_per_week),
    (utc_month, 1.0, duration_month),
    (utc_month, 3.0, 3.0 * duration_month),
    (utc_year, 1.0, duration_year),
  ]
}

///|
/// d3's `tickInterval(start, stop, count)` for UTC time scales.
pub fn utc_tick_interval(
  start : Double,
  stop : Double,
  count : Double,
) -> TimeInterval? {
  let target = (stop - start).abs() / count
  let table = tick_table()
  // bisector(step).right: the number of entries with step <= target
  let mut i = 0
  while i < table.length() && table[i].2 <= target {
    i = i + 1
  }
  if i == table.length() {
    return utc_year.every(
      @stats.tick_step(start / duration_year, stop / duration_year, count),
    )
  }
  if i == 0 {
    return utc_millisecond.every(
      @util.js_max(@stats.tick_step(start, stop, count), 1.0),
    )
  }
  let pick = if target / table[i - 1].2 < table[i].2 / target {
    i - 1
  } else {
    i
  }
  let (t, step, _) = table[pick]
  t.every(step)
}

///|
/// Tick values of a UTC time scale over [start, stop] (either order) for an
/// approximate tick count.
pub fn utc_ticks(
  start : Double,
  stop : Double,
  count : Double,
) -> Array[Double] {
  let reverse = stop < start
  let (a, b) = if reverse { (stop, start) } else { (start, stop) }
  let interval = utc_tick_interval(a, b, count)
  let out = match interval {
    Some(iv) => iv.range(a, b + 1.0)
    None => []
  }
  if reverse {
    out.rev_in_place()
  }
  out
}

///|
/// Tick values for an explicit interval (`tickCount: {interval, step}`).
pub fn utc_ticks_for(
  start : Double,
  stop : Double,
  interval : TimeInterval,
) -> Array[Double] {
  let reverse = stop < start
  let (a, b) = if reverse { (stop, start) } else { (start, stop) }
  let out = interval.range(a, b + 1.0)
  if reverse {
    out.rev_in_place()
  }
  out
}

///|
/// d3-scale's `nice` for a two-element domain and an interval.
pub fn nice_domain(
  d0 : Double,
  d1 : Double,
  interval : TimeInterval,
) -> (Double, Double) {
  if d1 < d0 {
    (interval.ceil(d0), interval.floor(d1))
  } else {
    (interval.floor(d0), interval.ceil(d1))
  }
}

///|
/// A time scale's `nice(count)`: widen the domain to nice tick boundaries.
pub fn utc_nice(d0 : Double, d1 : Double, count : Double) -> (Double, Double) {
  match utc_tick_interval(d0, d1, count) {
    Some(iv) => nice_domain(d0, d1, iv)
    None => (d0, d1)
  }
}
