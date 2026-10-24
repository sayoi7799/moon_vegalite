// Time units of encoding channels: parts, titles, axis formats.

///|
let unit_parts_order : Array[String] = [
  "year", "quarter", "month", "week", "day", "dayofyear", "date", "hours", "minutes",
  "seconds", "milliseconds",
]

///|
/// The single units of a vega-lite time unit name (`yearmonth` -> year, month).
fn unit_parts(name : String) -> Array[String] raise CompileError {
  let found : Array[String] = []
  let mut rest = name
  while rest.length() > 0 {
    let mut matched = false
    // longest token first so `dayofyear` wins over `day`
    for
      tok in [
        "dayofyear", "milliseconds", "year", "quarter", "month", "week", "day", "date",
        "hours", "minutes", "seconds",
      ] {
      if !matched && rest.has_prefix(tok) {
        found.push(tok)
        rest = rest[tok.length():].to_owned()
        matched = true
      }
    }
    if !matched {
      raise CompileError("timeUnit " + name + " 暂不支持")
    }
  }
  unit_parts_order.filter(fn(p) { found.contains(p) })
}

///|
/// Milliseconds of one smallest unit, used as the axis `tickMinStep`.
fn unit_duration(parts : Array[String]) -> Double? {
  if parts.length() == 0 {
    return None
  }
  match parts[parts.length() - 1] {
    "year" => Some(31536000000.0)
    "quarter" => Some(7776000000.0)
    "month" => Some(2678400000.0)
    "week" => Some(604800000.0)
    "date" => Some(86400000.0)
    "hours" => Some(3600000.0)
    "minutes" => Some(60000.0)
    "seconds" => Some(1000.0)
    "milliseconds" => Some(1.0)
    _ => None
  }
}

///|
/// vega-time `timeUnitSpecifier` with vega-lite's overrides.
fn time_unit_specifier(parts : Array[String]) -> String {
  let defaults : Map[String, String] = Map::from_array([
    ("year", "%Y "),
    ("quarter", "Q%q "),
    ("month", "%b "),
    ("date", "%d "),
    ("week", "W%U "),
    ("day", "%a "),
    ("dayofyear", "%j "),
    ("hours", "%H:00"),
    ("minutes", "00:%M"),
    ("seconds", ":%S"),
    ("milliseconds", ".%L"),
    ("year-month", "%b %Y "),
    ("year-month-date", "%b %d, %Y "),
    ("hours-minutes", "%H:%M"),
  ])
  let mut fmt = ""
  let mut start = 0
  let n = parts.length()
  while start < n {
    let mut end = n
    let mut hit = false
    while end > start && !hit {
      let key = parts[start:end].to_owned().join("-")
      match defaults.get(key) {
        Some(f) => {
          fmt = fmt + f
          start = end
          hit = true
        }
        None => end -= 1
      }
    }
    if !hit {
      start += 1
    }
  }
  @value.trim_js(fmt)
}
