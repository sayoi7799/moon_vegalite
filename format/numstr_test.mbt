///|
/// Decode `\uXXXX` escapes used by the fixture generator.
fn unescape(s : String) -> String {
  let out = StringBuilder()
  let cs = s.to_array()
  let mut i = 0
  while i < cs.length() {
    if cs[i] == '\\' && i + 5 < cs.length() + 0 && cs[i + 1] == 'u' {
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
/// Fixture lines of one kind, split on '|' (the last field keeps any further '|').
fn fixture_cases(kind : String) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for line in @formatcases.cases.split("\n") {
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

///|
test "to_fixed matches Number#toFixed" {
  let cs = fixture_cases("fixed")
  assert_true(cs.length() > 1000)
  for p in cs {
    let x = @util.double_from_hex(p[1])
    let f : Int32 = @string.from_str(p[2])
    let got = @format.to_fixed(x, f)
    if got != unescape(p[3]) {
      fail("(\{x}).toFixed(\{f}) [\{p[1]}]: expected \{p[3]}, got \{got}")
    }
  }
}

///|
test "to_exponential matches Number#toExponential" {
  let cs = fixture_cases("exp")
  assert_true(cs.length() > 1000)
  for p in cs {
    let x = @util.double_from_hex(p[1])
    let got = if p[2] == "-" {
      @format.to_exponential_shortest(x)
    } else {
      @format.to_exponential(x, @string.from_str(p[2]))
    }
    if got != unescape(p[3]) {
      fail(
        "(\{x}).toExponential(\{p[2]}) [\{p[1]}]: expected \{p[3]}, got \{got}",
      )
    }
  }
}

///|
test "to_precision matches Number#toPrecision" {
  let cs = fixture_cases("prec")
  assert_true(cs.length() > 1000)
  for p in cs {
    let x = @util.double_from_hex(p[1])
    let n : Int32 = @string.from_str(p[2])
    let got = @format.to_precision(x, n)
    if got != unescape(p[3]) {
      fail("(\{x}).toPrecision(\{n}) [\{p[1]}]: expected \{p[3]}, got \{got}")
    }
  }
}
