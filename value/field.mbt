// Field access paths as understood by vega-util `field()` / `splitAccessPath`:
// `a.b`, `a[0]`, `a["b.c"]` and backslash-escaped dots (`a\.b`).
// A data row is a `Map[String, Value]` in insertion order.

///|
/// Split an access path into its property names.
pub fn split_access_path(path : String) -> Array[String] {
  let cs = path.to_array()
  let n = cs.length()
  let parts : Array[String] = []
  let cur = StringBuilder()
  let mut have = false
  let mut i = 0
  while i < n {
    let c = cs[i]
    if c == '\\' && i + 1 < n {
      cur.write_char(cs[i + 1])
      have = true
      i = i + 2
    } else if c == '.' {
      parts.push(cur.to_string())
      cur.reset()
      have = false
      i = i + 1
    } else if c == '[' {
      if have {
        parts.push(cur.to_string())
        cur.reset()
        have = false
      }
      i = i + 1
      if i < n && c_is_quote(cs[i]) {
        let q = cs[i]
        i = i + 1
        while i < n && cs[i] != q {
          if cs[i] == '\\' && i + 1 < n {
            i = i + 1
          }
          cur.write_char(cs[i])
          i = i + 1
        }
        i = i + 1
      } else {
        while i < n && cs[i] != ']' {
          cur.write_char(cs[i])
          i = i + 1
        }
      }
      parts.push(cur.to_string())
      cur.reset()
      have = false
      if i < n && cs[i] == ']' {
        i = i + 1
      }
      // a following '.' only separates
      if i < n && cs[i] == '.' {
        i = i + 1
      }
    } else {
      cur.write_char(c)
      have = true
      i = i + 1
    }
  }
  if have || parts.length() == 0 {
    parts.push(cur.to_string())
  }
  parts
}

///|
fn c_is_quote(c : Char) -> Bool {
  c == '"' || c == '\''
}

///|
/// Read a (possibly nested) field of a row; `Undef` when any step is missing.
pub fn get_field(row : Map[String, Value], path : String) -> Value {
  let parts = split_access_path(path)
  let mut cur : Value = match row.get(parts[0]) {
    Some(v) => v
    None => Undef
  }
  for k in 1..<parts.length() {
    cur = match cur {
      Obj(m) =>
        match m.get(parts[k]) {
          Some(v) => v
          None => Undef
        }
      Arr(items) => {
        let idx = string_to_number(parts[k])
        if idx >= 0.0 && idx == idx.trunc() && idx < items.length().to_double() {
          items[idx.to_int()]
        } else {
          Undef
        }
      }
      _ => Undef
    }
  }
  cur
}
