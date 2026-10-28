///|
fn libm_cases(kind : String) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for line in @libm.cases.split("\n") {
    let parts = line.split(" ").map(fn(s) { s.to_owned() }).collect()
    if parts[0] == kind {
      out.push(parts)
    }
  }
  out
}

///|
test "js_log matches V8 Math.log bit for bit" {
  let cs = libm_cases("log")
  assert_true(cs.length() > 1000)
  for p in cs {
    let x = @util.double_from_hex(p[1])
    let got = @util.double_to_hex(@util.js_log(x))
    if got != p[2] {
      fail("Math.log(\{x}) [\{p[1]}]: expected \{p[2]}, got \{got}")
    }
  }
}

///|
test "js_log10 matches V8 Math.log10 bit for bit" {
  let cs = libm_cases("log10")
  assert_true(cs.length() > 1000)
  for p in cs {
    let x = @util.double_from_hex(p[1])
    let got = @util.double_to_hex(@util.js_log10(x))
    if got != p[2] {
      fail("Math.log10(\{x}) [\{p[1]}]: expected \{p[2]}, got \{got}")
    }
  }
}

///|
test "js_pow10 is exact for integer exponents and finite for others" {
  assert_eq(@util.js_pow10(0.0), 1.0)
  assert_eq(@util.js_pow10(3.0), 1000.0)
  assert_eq(@util.js_pow10(-2.0), 0.01)
  assert_true(@util.js_pow10(400.0).is_inf())
  assert_true(@util.js_pow10(0.5) > 3.16 && @util.js_pow10(0.5) < 3.17)
}

///|
test "js_cos / js_sin agree with V8 for whole degrees" {
  let d = 3.141592653589793 / 180.0
  assert_eq(@util.js_sin(45.0 * d), 0.7071067811865475)
  assert_eq(@util.js_cos(45.0 * d), 0.7071067811865476)
  assert_eq(@util.js_cos(90.0 * d), 6.123233995736766e-17)
  assert_eq(@util.js_cos(270.0 * d), -1.8369701987210297e-16)
  assert_eq(@util.js_sin(-90.0 * d), -1.0)
  assert_eq(@util.js_cos(0.0), 1.0)
}

///|
test "js_pow10 is the correctly rounded power of ten for every finite exponent" {
  for k in -323..<=308 {
    let expected = @string.parse_double("1e" + k.to_string())
    assert_eq(
      @util.double_to_hex(@util.js_pow10(k.to_double())),
      @util.double_to_hex(expected),
    )
  }
  // beyond the finite range the table holds 0 and +Infinity
  assert_eq(@util.js_pow10(-330.0), 0.0)
  assert_true(@util.js_pow10(310.0).is_inf())
  // 10^23 is the classic case where Math.pow(10, 23) in some V8 builds is one ulp off
  assert_eq(@util.js_pow10(23.0), 1.0e23)
}
