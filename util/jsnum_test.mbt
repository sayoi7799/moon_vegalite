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
    let x = @util.double_from_hex(p[1])
    let got = @util.js_number_to_string(x)
    if got != p[2] {
      fail("String(\{p[1]}): expected \{p[2]}, got \{got}")
    }
  }
}

///|
test "Double parsing round-trips JavaScript number text" {
  for p in cases("numstr") {
    let x = @util.double_from_hex(p[1])
    if x.is_nan() || x.is_inf() || x == 0.0 {
      continue
    }
    let y : Double = @string.from_str(p[2])
    if !@util.same_bits(x, y) {
      fail("parse(\{p[2]}) lost bits of \{p[1]}")
    }
  }
}

///|
test "js_round matches Math.round" {
  for p in cases("round") {
    let x = @util.double_from_hex(p[1])
    let expected = @util.double_from_hex(p[2])
    let got = @util.js_round(x)
    if !@util.same_bits(got, expected) {
      fail("Math.round(\{p[1]}): expected bits \{p[2]}, got \{got}")
    }
  }
}

///|
test "js_to_int32 matches ~~x" {
  for p in cases("int32") {
    let x = @util.double_from_hex(p[1])
    let expected : Int32 = @string.from_str(p[2])
    assert_eq(@util.js_to_int32(x), expected)
  }
}

///|
test "js_max and js_min follow Math.max / Math.min" {
  assert_true(@util.js_max(1.0, @double.not_a_number).is_nan())
  assert_true(@util.js_min(@double.not_a_number, 1.0).is_nan())
  assert_eq(@util.js_max(0.0, 3.0), 3.0)
  assert_eq(@util.js_min(-2.0, 3.0), -2.0)
  assert_true(@util.same_bits(@util.js_max(-0.0, 0.0), 0.0))
  assert_true(@util.same_bits(@util.js_min(0.0, -0.0), -0.0))
}
