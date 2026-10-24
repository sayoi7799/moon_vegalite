// Port of d3-time-format 4.1 (ISC license) with the en-US locale, UTC flavour:
// `utcFormat` and `utcParse`, plus vega-format's default multi-scale formatter.
// https://github.com/d3/d3-time-format

///|
let periods : Array[String] = ["AM", "PM"]

///|
let weekdays : Array[String] = [
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
]

///|
let short_weekdays : Array[String] = [
  "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
]

///|
let months : Array[String] = [
  "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December",
]

///|
let short_months : Array[String] = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]

///|
let locale_date : String = "%-m/%-d/%Y"

///|
let locale_time : String = "%-I:%M:%S %p"

///|
let locale_date_time : String = "%x, %X"

///|
/// d3's `pad(value, fill, width)`.
fn pad(value : Int32, fill : String, width : Int32) -> String {
  let sign = if value < 0 { "-" } else { "" }
  let s = (if value < 0 { -value } else { value }).to_string()
  sign +
  (if s.length() < width { fill.repeat(width - s.length()) + s } else { s })
}

///|
fn pad_for(c : String) -> String? {
  match c {
    "-" => Some("")
    "_" => Some(" ")
    "0" => Some("0")
    _ => None
  }
}

///|
fn iso_week_day(t : Double) -> Double {
  let day = utc_parts(t).day
  if day >= 4 || day == 0 {
    utc_thursday.floor(t)
  } else {
    utc_thursday.ceil(t)
  }
}

///|
fn count_between(iv : TimeInterval, a : Double, b : Double) -> Int32 {
  match iv.count(a, b) {
    Some(c) => c.to_int()
    None => 0
  }
}

///|
/// d3-time-format applied to an Invalid Date: numeric directives print "NaN"
/// (padded like any other number), names print nothing.
fn directive_invalid(c : String, p : String) -> String? {
  let padded = fn(width : Int32) {
    if "NaN".length() < width {
      p.repeat(width - 3) + "NaN"
    } else {
      "NaN"
    }
  }
  match c {
    "a" | "A" | "b" | "B" => Some("")
    "c" => Some(format_with(locale_date_time, @double.not_a_number))
    "x" => Some(format_with(locale_date, @double.not_a_number))
    "X" => Some(format_with(locale_time, @double.not_a_number))
    "d" | "e" | "H" | "I" | "m" | "M" | "S" | "U" | "V" | "W" | "g" | "y" =>
      Some(padded(2))
    "j" | "L" => Some(padded(3))
    "f" => Some(padded(3) + "000")
    "Y" | "G" => Some(padded(4))
    "p" => Some("AM")
    "q" => Some("1")
    "Q" | "s" | "u" | "w" => Some("NaN")
    "Z" => Some("+0000")
    "%" => Some("%")
    _ => None
  }
}

///|
/// The text of one `%` directive, or None when the directive is unknown.
fn directive(c : String, p : String, t : Double) -> String? {
  if t.is_nan() {
    return directive_invalid(c, p)
  }
  let parts = utc_parts(t)
  match c {
    "a" => Some(short_weekdays[parts.day])
    "A" => Some(weekdays[parts.day])
    "b" => Some(short_months[parts.month])
    "B" => Some(months[parts.month])
    "c" => Some(format_with(locale_date_time, t))
    "d" => Some(pad(parts.date, p, 2))
    "e" => Some(pad(parts.date, p, 2))
    "f" => Some(pad(parts.millis, p, 3) + "000")
    "g" => Some(pad(utc_parts(iso_week_day(t)).year % 100, p, 2))
    "G" => Some(pad(utc_parts(iso_week_day(t)).year % 10000, p, 4))
    "H" => Some(pad(parts.hours, p, 2))
    "I" =>
      Some(pad(if parts.hours % 12 == 0 { 12 } else { parts.hours % 12 }, p, 2))
    "j" => Some(pad(1 + count_between(utc_day, utc_year.floor(t), t), p, 3))
    "L" => Some(pad(parts.millis, p, 3))
    "m" => Some(pad(parts.month + 1, p, 2))
    "M" => Some(pad(parts.minutes, p, 2))
    "p" => Some(periods[if parts.hours >= 12 { 1 } else { 0 }])
    "q" => Some((1 + parts.month / 3).to_string())
    "Q" => Some(@util.js_number_to_string(t))
    "s" => Some(@util.js_number_to_string((t / 1000.0).floor()))
    "S" => Some(pad(parts.seconds, p, 2))
    "u" => Some((if parts.day == 0 { 7 } else { parts.day }).to_string())
    "U" =>
      Some(pad(count_between(utc_sunday, utc_year.floor(t) - 1.0, t), p, 2))
    "V" => {
      let d = iso_week_day(t)
      let y0 = utc_year.floor(d)
      let extra = if utc_parts(y0).day == 4 { 1 } else { 0 }
      Some(pad(count_between(utc_thursday, y0, d) + extra, p, 2))
    }
    "w" => Some(parts.day.to_string())
    "W" =>
      Some(pad(count_between(utc_monday, utc_year.floor(t) - 1.0, t), p, 2))
    "x" => Some(format_with(locale_date, t))
    "X" => Some(format_with(locale_time, t))
    "y" => Some(pad(parts.year % 100, p, 2))
    "Y" => Some(pad(parts.year % 10000, p, 4))
    "Z" => Some("+0000")
    "%" => Some("%")
    _ => None
  }
}

///|
/// d3's `newFormat(specifier, utcFormats)` applied to one instant.
fn format_with(spec : String, t : Double) -> String {
  let cs = spec.to_array()
  let n = cs.length()
  let out = StringBuilder()
  let mut i = 0
  while i < n {
    if cs[i] == '%' {
      i = i + 1
      let mut c = if i < n { cs[i].to_string() } else { "" }
      let p = match pad_for(c) {
        Some(p) => {
          i = i + 1
          c = if i < n { cs[i].to_string() } else { "" }
          p
        }
        None => if c == "e" { " " } else { "0" }
      }
      match directive(c, p, t) {
        Some(s) => out.write_string(s)
        None => out.write_string(c)
      }
      i = i + 1
    } else {
      out.write_char(cs[i])
      i = i + 1
    }
  }
  out.to_string()
}

///|
/// `d3.utcFormat(specifier)`.
pub fn utc_format(spec : String) -> (Double) -> String {
  fn(t : Double) { format_with(spec, t) }
}

///|
/// vega-format's default time formatter for a time axis: picks a format from
/// the precision of the instant being labelled.
pub fn utc_multi_format() -> (Double) -> String {
  let l = utc_format(".%L")
  let s = utc_format(":%S")
  let m = utc_format("%I:%M")
  let h = utc_format("%I %p")
  let d = utc_format("%a %d")
  let w = utc_format("%b %d")
  let mo = utc_format("%B")
  let q = utc_format("%B")
  let y = utc_format("%Y")
  let quarter = utc_month.every(3.0)
  fn(t : Double) {
    let f = if utc_second.floor(t) < t {
      l
    } else if utc_minute.floor(t) < t {
      s
    } else if utc_hour.floor(t) < t {
      m
    } else if utc_day.floor(t) < t {
      h
    } else if utc_month.floor(t) < t {
      if utc_sunday.floor(t) < t {
        d
      } else {
        w
      }
    } else if utc_year.floor(t) < t {
      match quarter {
        Some(qi) => if qi.floor(t) < t { mo } else { q }
        None => mo
      }
    } else {
      y
    }
    f(t)
  }
}

// ---- parsing ----

///|
priv struct ParseState {
  mut year : Double
  mut month : Double?
  mut day : Double
  mut hour : Double
  mut minute : Double
  mut second : Double
  mut milli : Double?
  mut zone : Double?
  mut ampm : Double?
  mut quarter : Double?
  mut unix_ms : Double?
  mut unix_s : Double?
  mut weekday_sun : Double?
  mut weekday_mon : Double?
  mut week_sun : Double?
  mut week_iso : Double?
  mut week_mon : Double?
}

///|
fn is_space_char(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
/// `/^\s*\d+/` on `cs[i:i+limit]`: the numeric value and the number of
/// characters consumed, or None.
fn match_number(cs : Array[Char], i : Int32, limit : Int32) -> (Double, Int32)? {
  let end = if limit < 0 || i + limit > cs.length() {
    cs.length()
  } else {
    i + limit
  }
  let mut j = i
  while j < end && is_space_char(cs[j]) {
    j = j + 1
  }
  let start = j
  let mut v = 0.0
  while j < end && cs[j] >= '0' && cs[j] <= '9' {
    v = v * 10.0 + (cs[j].to_int() - '0'.to_int()).to_double()
    j = j + 1
  }
  if j == start {
    None
  } else {
    Some((v, j - i))
  }
}

///|
/// Case-insensitive prefix match against `names` (first alternative wins).
fn match_name(
  names : Array[String],
  cs : Array[Char],
  i : Int32,
) -> (Int32, Int32)? {
  for k in 0..<names.length() {
    let name = names[k].to_lower().to_array()
    if i + name.length() <= cs.length() {
      let mut ok = true
      for j in 0..<name.length() {
        if cs[i + j].to_string().to_lower() != name[j].to_string() {
          ok = false
          break
        }
      }
      if ok {
        return Some((k, name.length()))
      }
    }
  }
  None
}

///|
fn parse_directive(
  st : ParseState,
  c : String,
  cs : Array[Char],
  i : Int32,
) -> Int32 {
  fn num(limit : Int32, set : (Double) -> Unit) -> Int32 {
    match match_number(cs, i, limit) {
      Some((v, len)) => {
        set(v)
        i + len
      }
      None => -1
    }
  }

  match c {
    "a" =>
      match match_name(short_weekdays, cs, i) {
        Some((k, len)) => {
          st.weekday_sun = Some(k.to_double())
          i + len
        }
        None => -1
      }
    "A" =>
      match match_name(weekdays, cs, i) {
        Some((k, len)) => {
          st.weekday_sun = Some(k.to_double())
          i + len
        }
        None => -1
      }
    "b" =>
      match match_name(short_months, cs, i) {
        Some((k, len)) => {
          st.month = Some(k.to_double())
          i + len
        }
        None => -1
      }
    "B" =>
      match match_name(months, cs, i) {
        Some((k, len)) => {
          st.month = Some(k.to_double())
          i + len
        }
        None => -1
      }
    "c" => parse_spec(st, locale_date_time, cs, i)
    "d" | "e" => num(2, fn(v) { st.day = v })
    "f" => num(6, fn(v) { st.milli = Some((v / 1000.0).floor()) })
    "g" =>
      num(2, fn(v) { st.year = v + (if v > 68.0 { 1900.0 } else { 2000.0 }) })
    "G" => num(4, fn(v) { st.year = v })
    "H" | "I" => num(2, fn(v) { st.hour = v })
    "j" =>
      num(3, fn(v) {
        st.month = Some(0.0)
        st.day = v
      })
    "L" => num(3, fn(v) { st.milli = Some(v) })
    "m" => num(2, fn(v) { st.month = Some(v - 1.0) })
    "M" => num(2, fn(v) { st.minute = v })
    "p" =>
      match match_name(periods, cs, i) {
        Some((k, len)) => {
          st.ampm = Some(k.to_double())
          i + len
        }
        None => -1
      }
    "q" => num(1, fn(v) { st.quarter = Some(v * 3.0 - 3.0) })
    "Q" => num(-1, fn(v) { st.unix_ms = Some(v) })
    "s" => num(-1, fn(v) { st.unix_s = Some(v) })
    "S" => num(2, fn(v) { st.second = v })
    "u" => num(1, fn(v) { st.weekday_mon = Some(v) })
    "U" => num(2, fn(v) { st.week_sun = Some(v) })
    "V" => num(2, fn(v) { st.week_iso = Some(v) })
    "w" => num(1, fn(v) { st.weekday_sun = Some(v) })
    "W" => num(2, fn(v) { st.week_mon = Some(v) })
    "x" => parse_spec(st, locale_date, cs, i)
    "X" => parse_spec(st, locale_time, cs, i)
    "y" =>
      num(2, fn(v) { st.year = v + (if v > 68.0 { 1900.0 } else { 2000.0 }) })
    "Y" => num(4, fn(v) { st.year = v })
    "Z" => parse_zone(st, cs, i)
    "%" => if i < cs.length() && cs[i] == '%' { i + 1 } else { -1 }
    _ => -1
  }
}

///|
/// `/^(Z)|([+-]\d\d)(?::?(\d\d))?/` at the start of `cs[i:i+6]`.
fn parse_zone(st : ParseState, cs : Array[Char], i : Int32) -> Int32 {
  let end = if i + 6 > cs.length() { cs.length() } else { i + 6 }
  if i < end && cs[i] == 'Z' {
    st.zone = Some(0.0)
    return i + 1
  }
  if i + 2 < end + 0 &&
    (cs[i] == '+' || cs[i] == '-') &&
    cs[i + 1] >= '0' &&
    cs[i + 1] <= '9' &&
    cs[i + 2] >= '0' &&
    cs[i + 2] <= '9' {
    let hh = ((cs[i + 1].to_int() - 48) * 10 + (cs[i + 2].to_int() - 48)).to_double()
    let mut j = i + 3
    let mut mm = 0.0
    let mut k = j
    if k < end && cs[k] == ':' {
      k = k + 1
    }
    if k + 1 < end + 0 &&
      cs[k] >= '0' &&
      cs[k] <= '9' &&
      cs[k + 1] >= '0' &&
      cs[k + 1] <= '9' {
      mm = ((cs[k].to_int() - 48) * 10 + (cs[k + 1].to_int() - 48)).to_double()
      j = k + 2
    }
    let v = hh * 100.0 + mm
    st.zone = Some(if cs[i] == '-' { v } else { -v })
    return j
  }
  -1
}

///|
fn parse_spec(
  st : ParseState,
  spec : String,
  cs : Array[Char],
  j0 : Int32,
) -> Int32 {
  let sp = spec.to_array()
  let n = sp.length()
  let m = cs.length()
  let mut i = 0
  let mut j = j0
  while i < n {
    if j >= m {
      return -1
    }
    let c = sp[i]
    i = i + 1
    if c == '%' {
      let mut d = if i < n { sp[i].to_string() } else { "" }
      i = i + 1
      if pad_for(d) is Some(_) {
        d = if i < n { sp[i].to_string() } else { "" }
        i = i + 1
      }
      j = parse_directive(st, d, cs, j)
      if j < 0 {
        return -1
      }
    } else {
      if c != cs[j] {
        return -1
      }
      j = j + 1
    }
  }
  j
}

///|
/// JavaScript's `Date.UTC` with the year used as-is when below 100 (what
/// d3-time-format's `utcDate` does through `setUTCFullYear`).
fn utc_date_fields(
  y : Double,
  mo : Double,
  d : Double,
  h : Double,
  mi : Double,
  s : Double,
  l : Double,
) -> Double {
  if y >= 0.0 && y < 100.0 {
    utc_ms_exact_year(y, mo, d, h, mi, s, l)
  } else {
    utc_ms(y, mo, d, h, mi, s, l)
  }
}

///|
/// `d3.utcParse(specifier)`: None when the text does not match.
pub fn utc_parse(spec : String) -> (String) -> Double? {
  fn(text : String) {
    let cs = text.to_array()
    let st : ParseState = {
      year: 1900.0,
      month: None,
      day: 1.0,
      hour: 0.0,
      minute: 0.0,
      second: 0.0,
      milli: None,
      zone: None,
      ampm: None,
      quarter: None,
      unix_ms: None,
      unix_s: None,
      weekday_sun: None,
      weekday_mon: None,
      week_sun: None,
      week_iso: None,
      week_mon: None,
    }
    let i = parse_spec(st, spec, cs, 0)
    if i != cs.length() {
      return None
    }
    match st.unix_ms {
      Some(q) => return Some(time_clip(q))
      None => ()
    }
    match st.unix_s {
      Some(s) => return Some(time_clip(s * 1000.0 + st.milli.unwrap_or(0.0)))
      None => ()
    }
    if st.zone is None {
      st.zone = Some(0.0)
    }
    match st.ampm {
      Some(p) => st.hour = st.hour.mod(12.0) + p * 12.0
      None => ()
    }
    if st.month is None {
      st.month = Some(st.quarter.unwrap_or(0.0))
    }
    if st.week_iso is Some(v) {
      if v < 1.0 || v > 53.0 {
        return None
      }
      if st.weekday_sun is None {
        st.weekday_sun = Some(1.0)
      }
      let w = st.weekday_sun.unwrap_or(1.0)
      let jan1 = utc_date_fields(st.year, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0)
      let day = utc_parts(jan1).day
      let week0 = if day > 4 || day == 0 {
        utc_monday.ceil(jan1)
      } else {
        utc_monday.floor(jan1)
      }
      let week = utc_day.offset(week0, ((v - 1.0) * 7.0).to_int())
      let wp = utc_parts(week)
      st.year = wp.year.to_double()
      st.month = Some(wp.month.to_double())
      st.day = wp.date.to_double() + (w + 6.0).mod(7.0)
    } else if st.week_mon is Some(_) || st.week_sun is Some(_) {
      if st.weekday_sun is None {
        st.weekday_sun = Some(
          match st.weekday_mon {
            Some(u) => u.mod(7.0)
            None => if st.week_mon is Some(_) { 1.0 } else { 0.0 }
          },
        )
      }
      let w = st.weekday_sun.unwrap_or(0.0)
      let jan1 = utc_date_fields(st.year, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0)
      let day = utc_parts(jan1).day.to_double()
      st.month = Some(0.0)
      st.day = match st.week_mon {
        Some(wm) => (w + 6.0).mod(7.0) + wm * 7.0 - (day + 5.0).mod(7.0)
        None => w + st.week_sun.unwrap_or(0.0) * 7.0 - (day + 6.0).mod(7.0)
      }
    }
    let z = st.zone.unwrap_or(0.0)
    // JavaScript: d.H += d.Z / 100 | 0; d.M += d.Z % 100
    let hour = st.hour + (z / 100.0).trunc()
    let minute = st.minute + z.mod(100.0)
    let milli = st.milli.unwrap_or(0.0)
    let r = utc_date_fields(
      st.year,
      st.month.unwrap_or(0.0),
      st.day,
      hour,
      minute,
      st.second,
      milli,
    )
    Some(r)
  }
}
