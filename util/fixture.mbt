// Helpers for reading the generated test fixtures (see scripts/gen_fixtures.mjs).

///|
/// Decode the `\uXXXX` escapes the fixture generator uses to keep every
/// fixture line printable ASCII.
pub fn unescape_fixture(s : String) -> String {
  let out = StringBuilder()
  let cs = s.to_array()
  let mut i = 0
  while i < cs.length() {
    if cs[i] == '\\' && i + 5 < cs.length() + 1 && cs[i + 1] == 'u' {
      let mut code = 0
      for j in 2..<6 {
        let c = cs[i + j].to_int()
        let d = if c >= 'a'.to_int() {
          c - 'a'.to_int() + 10
        } else {
          c - '0'.to_int()
        }
        code = code * 16 + d
      }
      out.write_char(code.unsafe_to_char())
      i = i + 6
    } else {
      out.write_char(cs[i])
      i = i + 1
    }
  }
  out.to_string()
}

///|
/// Split a fixture file into the '|'-separated fields of the lines whose
/// first field is `kind`.
pub fn fixture_lines(text : String, kind : String) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for line in text.split("\n") {
    let parts : Array[String] = line
      .split("|")
      .map(fn(s) { s.to_owned() })
      .collect()
    if parts[0] == kind {
      out.push(parts)
    }
  }
  out
}
