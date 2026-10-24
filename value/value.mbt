// Dynamic cell values and the JavaScript type coercions that Vega applies to
// data (`toNumber`, `toDate`, `toBoolean`, `toString`, `isValid`, `ascending`).
//
// Dates travel through Vega datasets as epoch milliseconds (numbers) or Date
// objects, which compare and intern like numbers, so there is no separate date
// variant here.

///|
pub(all) enum Value {
  /// JavaScript `undefined`: a missing field
  Undef
  Null
  Bool(Bool)
  Num(Double)
  Str(String)
  Arr(Array[Value])
  Obj(Map[String, Value])
}

///|
fn is_js_space(c : Char) -> Bool {
  let n = c.to_int()
  n == 9 ||
  n == 10 ||
  n == 11 ||
  n == 12 ||
  n == 13 ||
  n == 32 ||
  n == 0xA0 ||
  n == 0x1680 ||
  (n >= 0x2000 && n <= 0x200A) ||
  n == 0x2028 ||
  n == 0x2029 ||
  n == 0x202F ||
  n == 0x205F ||
  n == 0x3000 ||
  n == 0xFEFF
}

///|
pub fn trim_js(s : String) -> String {
  let cs = s.to_array()
  let mut a = 0
  let mut b = cs.length()
  while a < b && is_js_space(cs[a]) {
    a = a + 1
  }
  while b > a && is_js_space(cs[b - 1]) {
    b = b - 1
  }
  String::from_array(cs[a:b])
}

///|
fn digit_value(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'z' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'Z' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    99
  }
}

///|
/// JavaScript's `Number(string)` (`ToNumber` applied to a String).
pub fn string_to_number(s : String) -> Double {
  let t = trim_js(s)
  if t == "" {
    return 0.0
  }
  let cs = t.to_array()
  let n = cs.length()
  // 0x / 0o / 0b literals (no sign allowed)
  if n > 2 && cs[0] == '0' {
    let radix = match cs[1] {
      'x' | 'X' => 16
      'o' | 'O' => 8
      'b' | 'B' => 2
      _ => 0
    }
    if radix != 0 {
      let mut v = 0.0
      for i in 2..<n {
        let d = digit_value(cs[i])
        if d >= radix {
          return @double.not_a_number
        }
        v = v * radix.to_double() + d.to_double()
      }
      return v
    }
  }
  let mut i = 0
  let mut negative = false
  if cs[0] == '+' || cs[0] == '-' {
    negative = cs[0] == '-'
    i = 1
  }
  if t.unsafe_substring(start=i, end=n) == "Infinity" {
    return if negative { @double.neg_infinity } else { @double.infinity }
  }
  // StrDecimalLiteral: digits [. digits] | . digits, optional exponent
  let int_start = i
  while i < n && cs[i] >= '0' && cs[i] <= '9' {
    i = i + 1
  }
  let int_digits = i - int_start
  let mut frac_digits = 0
  if i < n && cs[i] == '.' {
    i = i + 1
    let f0 = i
    while i < n && cs[i] >= '0' && cs[i] <= '9' {
      i = i + 1
    }
    frac_digits = i - f0
  }
  if int_digits == 0 && frac_digits == 0 {
    return @double.not_a_number
  }
  if i < n && (cs[i] == 'e' || cs[i] == 'E') {
    i = i + 1
    if i < n && (cs[i] == '+' || cs[i] == '-') {
      i = i + 1
    }
    let e0 = i
    while i < n && cs[i] >= '0' && cs[i] <= '9' {
      i = i + 1
    }
    if i == e0 {
      return @double.not_a_number
    }
  }
  if i != n {
    return @double.not_a_number
  }
  // normalise ".5" and "5." for the parser
  let body = t.unsafe_substring(start=int_start, end=n)
  let norm = if int_digits == 0 { "0" + body } else { body }
  let norm2 = norm.replace(old=".e", new=".0e").replace(old=".E", new=".0E")
  let norm3 = if norm2.has_suffix(".") { norm2 + "0" } else { norm2 }
  // out-of-range literals overflow to Infinity or underflow to 0
  let v : Double = @string.from_str(norm3) catch {
    _ => {
      let exp_negative = norm3.contains("e-") || norm3.contains("E-")
      if exp_negative {
        0.0
      } else {
        @double.infinity
      }
    }
  }
  if negative {
    -v
  } else {
    v
  }
}

///|
/// `+value`: JavaScript's unary plus on a cell value.
pub fn Value::to_number(self : Value) -> Double {
  match self {
    Undef => @double.not_a_number
    Null => 0.0
    Bool(b) => if b { 1.0 } else { 0.0 }
    Num(x) => x
    Str(s) => string_to_number(s)
    Arr(items) =>
      match items.length() {
        0 => 0.0
        1 => items[0].to_number()
        _ => @double.not_a_number
      }
    Obj(_) => @double.not_a_number
  }
}

///|
/// `String(value)`.
pub fn Value::to_js_string(self : Value) -> String {
  match self {
    Undef => "undefined"
    Null => "null"
    Bool(b) => if b { "true" } else { "false" }
    Num(x) => @util.js_number_to_string(x)
    Str(s) => s
    Arr(items) =>
      items
      .map(fn(v) {
        match v {
          Null | Undef => ""
          other => other.to_js_string()
        }
      })
      .join(",")
    Obj(_) => "[object Object]"
  }
}

///|
/// vega-lite / vega `isValid`: not null and not NaN.
pub fn Value::is_valid(self : Value) -> Bool {
  match self {
    Null | Undef => false
    Num(x) => !x.is_nan()
    _ => true
  }
}

///|
/// JavaScript truthiness.
pub fn Value::truthy(self : Value) -> Bool {
  match self {
    Null | Undef => false
    Bool(b) => b
    Num(x) => !(x == 0.0 || x.is_nan())
    Str(s) => s != ""
    _ => true
  }
}

///|
fn is_blank(v : Value) -> Bool {
  match v {
    Null | Undef => true
    Str("") => true
    _ => false
  }
}

///|
/// vega-util `toNumber`: null for null / "", else `+v`.
pub fn Value::coerce_number(self : Value) -> Value {
  if is_blank(self) {
    Null
  } else {
    Num(self.to_number())
  }
}

///|
/// vega-util `toString`: null for null / "", else `v + ""`.
pub fn Value::coerce_string(self : Value) -> Value {
  if is_blank(self) {
    Null
  } else {
    Str(self.to_js_string())
  }
}

///|
/// vega-util `toBoolean`.
pub fn Value::coerce_boolean(self : Value) -> Value {
  if is_blank(self) {
    return Null
  }
  match self {
    Str("false") | Str("0") => Bool(false)
    other => Bool(other.truthy())
  }
}

///|
/// vega-util `toDate` with the default parser: numbers pass through, strings
/// go through `Date.parse` (NaN when unparsable).
pub fn Value::coerce_date(self : Value) -> Value {
  if is_blank(self) {
    return Null
  }
  match self {
    Num(x) => Num(x)
    Str(s) => Num(parse_date(s))
    Bool(_) => Num(@double.not_a_number)
    other => Num(other.to_number())
  }
}

///|
/// vega-util `ascending`: nulls first, then natural order; NaN after numbers.
pub fn compare_values(u : Value, v : Value) -> Int32 {
  match (u, v) {
    (Null | Undef, Null | Undef) => 0
    (Null | Undef, _) => -1
    (_, Null | Undef) => 1
    (Num(a), Num(b)) =>
      if a < b {
        -1
      } else if a > b {
        1
      } else if a == b {
        0
      } else if a.is_nan() && !b.is_nan() {
        // vega: `v === v && u !== u` sorts NaN first
        -1
      } else if b.is_nan() && !a.is_nan() {
        1
      } else {
        0
      }
    (Str(a), Str(b)) => {
      let c = a.lexical_compare(b)
      if c < 0 {
        -1
      } else if c > 0 {
        1
      } else {
        0
      }
    }
    (Bool(a), Bool(b)) => if a == b { 0 } else if !a { -1 } else { 1 }
    _ => {
      // mixed types: compare as numbers when possible, like JavaScript
      let a = u.to_number()
      let b = v.to_number()
      if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    }
  }
}
