// `Date.parse` for the text formats that show up in chart data.
//
// V8's legacy date parser accepts a very large, loosely defined set of
// strings. This port handles ISO 8601 (ES5 format and the common space
// separated variants), `YYYY/MM/DD`, `M/D/YYYY`, month names in either order,
// weekday names, 12 and 24 hour times, and GMT / UTC / numeric offsets. Other
// inputs yield NaN (an invalid date). Local time is UTC (see the README).

///|
priv enum DateToken {
  Number(Double, Int32)
  Word(String)
  Sym(Char)
}

///|
fn tokenize(s : String) -> Array[DateToken] {
  let cs = s.to_array()
  let n = cs.length()
  let out : Array[DateToken] = []
  let mut i = 0
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      let mut v = 0.0
      let start = i
      while i < n && cs[i] >= '0' && cs[i] <= '9' {
        v = v * 10.0 + (cs[i].to_int() - 48).to_double()
        i = i + 1
      }
      out.push(Number(v, i - start))
    } else if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      let sb = StringBuilder()
      while i < n &&
            ((cs[i] >= 'a' && cs[i] <= 'z') || (cs[i] >= 'A' && cs[i] <= 'Z')) {
        sb.write_char(cs[i])
        i = i + 1
      }
      out.push(Word(sb.to_string().to_lower()))
    } else if c == '(' {
      // parenthesised text (e.g. a time zone name) is ignored
      while i < n && cs[i] != ')' {
        i = i + 1
      }
      i = i + 1
    } else {
      out.push(Sym(c))
      i = i + 1
    }
  }
  out
}

///|
fn month_of_word(w : String) -> Int32? {
  if w.length() < 3 {
    return None
  }
  let p = w.unsafe_substring(start=0, end=3)
  let names = [
    "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov",
    "dec",
  ]
  for i in 0..<12 {
    if names[i] == p {
      return Some(i + 1)
    }
  }
  None
}

///|
fn is_weekday_word(w : String) -> Bool {
  if w.length() < 3 {
    return false
  }
  let p = w.unsafe_substring(start=0, end=3)
  p == "sun" ||
  p == "mon" ||
  p == "tue" ||
  p == "wed" ||
  p == "thu" ||
  p == "fri" ||
  p == "sat"
}

///|
/// Offset in minutes east of UTC for a zone abbreviation, as V8 knows them.
fn zone_of_word(w : String) -> Int32? {
  match w {
    "z" | "gmt" | "utc" | "ut" => Some(0)
    "est" => Some(-300)
    "edt" => Some(-240)
    "cst" => Some(-360)
    "cdt" => Some(-300)
    "mst" => Some(-420)
    "mdt" => Some(-360)
    "pst" => Some(-480)
    "pdt" => Some(-420)
    _ => None
  }
}

///|
fn two_digit_year(y : Double, digits : Int32) -> Double {
  if digits <= 2 && y >= 0.0 && y < 50.0 {
    2000.0 + y
  } else if digits <= 2 && y >= 50.0 && y < 100.0 {
    1900.0 + y
  } else {
    y
  }
}

///|
fn finish_date(
  y : Double,
  mo : Double,
  d : Double,
  h : Double,
  mi : Double,
  s : Double,
  ms : Double,
  offset_minutes : Double,
) -> Double {
  if mo < 1.0 || mo > 12.0 || d < 1.0 || d > 31.0 {
    return @double.not_a_number
  }
  if h > 24.0 || mi > 59.0 || s > 59.0 {
    return @double.not_a_number
  }
  if h == 24.0 && (mi != 0.0 || s != 0.0 || ms != 0.0) {
    return @double.not_a_number
  }
  let t = @time.utc_ms_exact_year(y, mo - 1.0, d, h, mi, s, ms)
  t - offset_minutes * 60000.0
}

///|
fn ms_from_digits(text : String) -> Double {
  let cs = text.to_array()
  let mut v = 0
  for i in 0..<3 {
    v = v * 10 + (if i < cs.length() { cs[i].to_int() - 48 } else { 0 })
  }
  v.to_double()
}

///|
fn digits_at(cs : Array[Char], i : Int32, n : Int32) -> Double? {
  if i + n > cs.length() {
    return None
  }
  let mut v = 0.0
  for k in 0..<n {
    let c = cs[i + k]
    if c < '0' || c > '9' {
      return None
    }
    v = v * 10.0 + (c.to_int() - 48).to_double()
  }
  Some(v)
}

///|
/// ECMAScript date-time string format (and its space-separated relatives).
fn parse_iso(s : String) -> Double? {
  let cs = s.to_array()
  let n = cs.length()
  let mut i = 0
  let mut year = 0.0
  if n > 0 && (cs[0] == '+' || cs[0] == '-') {
    let sign = if cs[0] == '-' { -1.0 } else { 1.0 }
    match digits_at(cs, 1, 6) {
      Some(v) => {
        if sign < 0.0 && v == 0.0 {
          return Some(@double.not_a_number)
        }
        year = sign * v
        i = 7
      }
      None => return None
    }
  } else {
    match digits_at(cs, 0, 4) {
      Some(v) => {
        year = v
        i = 4
      }
      None => return None
    }
  }
  let mut month = 1.0
  let mut day = 1.0
  if i < n && cs[i] == '-' {
    match digits_at(cs, i + 1, 2) {
      Some(v) => {
        month = v
        i = i + 3
      }
      None => return None
    }
    if i < n && cs[i] == '-' {
      match digits_at(cs, i + 1, 2) {
        Some(v) => {
          day = v
          i = i + 3
        }
        None => return None
      }
    }
  }
  let mut hour = 0.0
  let mut minute = 0.0
  let mut second = 0.0
  let mut milli = 0.0
  let mut offset = 0.0
  if i < n {
    if cs[i] != 'T' && cs[i] != 't' && cs[i] != ' ' {
      return None
    }
    i = i + 1
    match digits_at(cs, i, 2) {
      Some(v) => hour = v
      None => return None
    }
    if i + 2 >= n || cs[i + 2] != ':' {
      return None
    }
    match digits_at(cs, i + 3, 2) {
      Some(v) => minute = v
      None => return None
    }
    i = i + 5
    if i < n && cs[i] == ':' {
      match digits_at(cs, i + 1, 2) {
        Some(v) => second = v
        None => return None
      }
      i = i + 3
      if i < n && (cs[i] == '.' || cs[i] == ',') {
        let sb = StringBuilder()
        i = i + 1
        while i < n && cs[i] >= '0' && cs[i] <= '9' {
          sb.write_char(cs[i])
          i = i + 1
        }
        let text = sb.to_string()
        if text == "" {
          return None
        }
        milli = ms_from_digits(text)
      }
    }
    if i < n {
      if cs[i] == 'Z' || cs[i] == 'z' {
        i = i + 1
      } else if cs[i] == '+' || cs[i] == '-' {
        let sign = if cs[i] == '-' { -1.0 } else { 1.0 }
        match digits_at(cs, i + 1, 2) {
          Some(hh) => {
            let mut j = i + 3
            let mut mm = 0.0
            if j < n && cs[j] == ':' {
              j = j + 1
            }
            match digits_at(cs, j, 2) {
              Some(v) => {
                mm = v
                j = j + 2
              }
              None => return None
            }
            offset = sign * (hh * 60.0 + mm)
            i = j
          }
          None => return None
        }
      }
    }
  }
  if i != n {
    return None
  }
  Some(finish_date(year, month, day, hour, minute, second, milli, offset))
}

///|
/// V8-style legacy parsing of loosely formatted dates.
fn parse_legacy(s : String) -> Double {
  let toks = tokenize(s)
  let n = toks.length()
  let nums : Array[(Double, Int32)] = []
  let mut month : Int32? = None
  let mut hour : Double? = None
  let mut minute = 0.0
  let mut second = 0.0
  let mut milli = 0.0
  let mut ampm : Int32? = None
  let mut zone : Int32? = None
  let mut seen_number = false
  let mut i = 0
  while i < n {
    match toks[i] {
      Number(v, digits) => {
        seen_number = true
        let next_colon = i + 1 < n && toks[i + 1] is Sym(':')
        if next_colon && hour is None {
          hour = Some(v)
          i = i + 2
          match toks.get(i) {
            Some(Number(m, _)) => {
              minute = m
              i = i + 1
            }
            _ => return @double.not_a_number
          }
          if i < n && toks[i] is Sym(':') {
            i = i + 1
            match toks.get(i) {
              Some(Number(sv, _)) => {
                second = sv
                i = i + 1
              }
              _ => return @double.not_a_number
            }
            if i < n && toks[i] is Sym('.') {
              i = i + 1
              match toks.get(i) {
                Some(Number(_, digits_f)) => {
                  // re-read the digits of the fraction from the source text
                  let frac = match toks[i] {
                    Number(fv, _) => fv
                    _ => 0.0
                  }
                  let text = padded_digits(frac, digits_f)
                  milli = ms_from_digits(text)
                  i = i + 1
                }
                _ => return @double.not_a_number
              }
            }
          }
        } else if i > 0 &&
          (toks[i - 1] is Sym('+') || toks[i - 1] is Sym('-')) &&
          (hour is Some(_) || zone is Some(_)) {
          // numeric offset after a time or a zone word, e.g. "10:00 +0100", "GMT+0100"
          let sign = if toks[i - 1] is Sym('-') { -1 } else { 1 }
          let (hh, mm, adv) = parse_offset(toks, i, v, digits)
          zone = Some(sign * (hh * 60 + mm))
          i = i + adv
        } else {
          nums.push((v, digits))
          i = i + 1
        }
      }
      Word(w) => {
        if month_of_word(w) is Some(m) && month is None {
          month = Some(m)
        } else if is_weekday_word(w) {
          ()
        } else if w == "am" || w == "pm" {
          ampm = Some(if w == "pm" { 1 } else { 0 })
        } else if zone_of_word(w) is Some(z) {
          zone = Some(z)
        } else if w == "t" {
          ()
        } else if !seen_number {
          ()
        } else {
          return @double.not_a_number
        }
        i = i + 1
      }
      Sym(_) => i = i + 1
    }
  }
  // assemble the date part
  let (y, mo, d) = match month {
    Some(m) =>
      match nums.length() {
        1 => {
          let (a, ad) = nums[0]
          if a <= 31.0 && ad <= 2 {
            (2001.0, m.to_double(), a)
          } else {
            (two_digit_year(a, ad), m.to_double(), 1.0)
          }
        }
        2 => {
          let (a, ad) = nums[0]
          let (b, bd) = nums[1]
          if a > 31.0 || ad >= 3 {
            (two_digit_year(a, ad), m.to_double(), b)
          } else {
            (two_digit_year(b, bd), m.to_double(), a)
          }
        }
        _ => return @double.not_a_number
      }
    None =>
      match nums.length() {
        3 => {
          let (a, ad) = nums[0]
          let (b, _) = nums[1]
          let (c, cd) = nums[2]
          if a > 31.0 || ad >= 3 {
            (two_digit_year(a, ad), b, c)
          } else {
            (two_digit_year(c, cd), a, b)
          }
        }
        2 => {
          let (a, _) = nums[0]
          let (b, _) = nums[1]
          (2001.0, a, b)
        }
        1 => {
          let (a, ad) = nums[0]
          if a > 31.0 || ad >= 3 {
            (a, 1.0, 1.0)
          } else {
            (2001.0, a, 1.0)
          }
        }
        _ => return @double.not_a_number
      }
  }
  let mut h = match hour {
    Some(v) => v
    None => 0.0
  }
  match ampm {
    Some(p) => {
      if h < 1.0 || h > 12.0 {
        return @double.not_a_number
      }
      h = h.mod(12.0) + (if p == 1 { 12.0 } else { 0.0 })
    }
    None => ()
  }
  let off = match zone {
    Some(z) => z.to_double()
    None => 0.0
  }
  finish_date(y, mo, d, h, minute, second, milli, off)
}

///|
fn padded_digits(v : Double, digits : Int32) -> String {
  let s = v.to_int64().to_string()
  "0".repeat(if digits > s.length() { digits - s.length() } else { 0 }) + s
}

///|
/// Hours / minutes of a numeric UTC offset starting at token `i` (value `v`
/// with `digits` digits); returns how many tokens were consumed.
fn parse_offset(
  toks : Array[DateToken],
  i : Int32,
  v : Double,
  digits : Int32,
) -> (Int32, Int32, Int32) {
  if digits >= 3 {
    let iv = v.to_int()
    (iv / 100, iv % 100, 1)
  } else {
    let hh = v.to_int()
    if i + 2 < toks.length() && toks[i + 1] is Sym(':') {
      match toks[i + 2] {
        Number(m, _) => (hh, m.to_int(), 3)
        _ => (hh, 0, 1)
      }
    } else {
      (hh, 0, 1)
    }
  }
}

///|
/// JavaScript's `Date.parse(text)`: epoch milliseconds, or NaN for an
/// unrecognised string.
pub fn parse_date(text : String) -> Double {
  let s = trim_js(text)
  if s == "" {
    return @double.not_a_number
  }
  match parse_iso(s) {
    Some(t) => t
    None =>
      // V8 treats a malformed ISO date-time (with a 'T' after the date) as
      // invalid instead of falling back to the lenient parser
      if looks_like_iso_datetime(s) {
        @double.not_a_number
      } else {
        parse_legacy(s)
      }
  }
}

///|
fn looks_like_iso_datetime(s : String) -> Bool {
  let cs = s.to_array()
  cs.length() > 10 &&
  (cs[10] == 'T' || cs[10] == 't') &&
  digits_at(cs, 0, 4) is Some(_) &&
  cs[4] == '-' &&
  digits_at(cs, 5, 2) is Some(_) &&
  cs[7] == '-' &&
  digits_at(cs, 8, 2) is Some(_)
}
