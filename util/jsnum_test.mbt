///|
fn hex_to_double(hex : String) -> Double {
  let mut bits = 0UL
  for c in hex {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - '0'.to_int()
    } else {
      c.to_int() - 'a'.to_int() + 10
    }
    bits = bits * 16UL + d.to_uint64()
  }
  bits.reinterpret_as_double()
}

///|
fn same_bits(a : Double, b : Double) -> Bool {
  a.reinterpret_as_uint64() == b.reinterpret_as_uint64() ||
  (a.is_nan() && b.is_nan())
}

///|
fn cases(kind : String) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for line in @numfmt.cases.split("\n") {
    let parts = line.split(" ").map(fn(s) { s.to_owned() }).collect()
    if parts[0] == kind {
      out.push(parts)
    }
  }
  out
}

///|
test "js_number_to_string matches JavaScript String(x)" {
  let cs = cases("numstr")
  assert_true(cs.length() > 1000)
  for p in cs {
    let x = hex_to_double(p[1])
    let got = @util.js_number_to_string(x)
    if got != p[2] {
      fail("String(\{p[1]}): expected \{p[2]}, got \{got}")
    }
  }
}

///|
test "Double parsing round-trips JavaScript number text" {
  for p in cases("numstr") {
    let x = hex_to_double(p[1])
    if x.is_nan() || x.is_inf() || x == 0.0 {
      continue
    }
    let y : Double = @string.from_str(p[2])
    if !same_bits(x, y) {
      fail("parse(\{p[2]}) lost bits of \{p[1]}")
    }
  }
}

///|
test "js_round matches Math.round" {
  for p in cases("round") {
    let x = hex_to_double(p[1])
    let expected = hex_to_double(p[2])
    let got = @util.js_round(x)
    if !same_bits(got, expected) {
      fail("Math.round(\{p[1]}): expected bits \{p[2]}, got \{got}")
    }
  }
}

///|
test "js_to_int32 matches ~~x" {
  for p in cases("int32") {
    let x = hex_to_double(p[1])
    let expected : Int32 = @string.from_str(p[2])
    assert_eq(@util.js_to_int32(x), expected)
  }
}
