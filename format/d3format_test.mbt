///|
fn must_format(spec : String) -> ((Double) -> String) raise {
  @format.format(spec) catch {
    FormatError(msg) => fail("format(\{spec}) raised \{msg}")
  }
}

///|
test "format matches d3-format (via the Vega locale)" {
  let cs = fixture_cases("fmt")
  assert_true(cs.length() > 5000)
  let mut checked = 0
  for p in cs {
    let spec = p[1]
    let x = @util.double_from_hex(p[2])
    let got = must_format(spec)(x)
    let expected = unescape(p[3])
    if got != expected {
      fail(
        "format(\"\{spec}\")(\{x}) [\{p[2]}]: expected \"\{p[3]}\", got \"\{got}\"",
      )
    }
    checked = checked + 1
  }
  assert_true(checked > 5000)
}

///|
test "format_float matches vega-format formatFloat" {
  let cs = fixture_cases("float")
  assert_true(cs.length() > 300)
  for p in cs {
    let spec = p[1]
    let x = @util.double_from_hex(p[2])
    let f = @format.format_float(spec) catch {
      FormatError(msg) => fail("format_float(\{spec}) raised \{msg}")
    }
    let got = f(x)
    let expected = unescape(p[3])
    if got != expected {
      fail(
        "formatFloat(\"\{spec}\")(\{x}) [\{p[2]}]: expected \"\{p[3]}\", got \"\{got}\"",
      )
    }
  }
}

///|
test "format_span matches vega-format formatSpan" {
  let cs = fixture_cases("span")
  assert_true(cs.length() > 100)
  let values : Array[Double] = [
    0.0, 1.0, -1.0, 0.5, 2.5, 5.0, 10.0, 25.0, 50.0, 100.0, -100.0, 0.001, 1500.0,
    123456.0, 1.0e6, -2.0e-7, 0.05, 3.5, 12400.0,
  ]
  for p in cs {
    let nums = p[1]
      .split(" ")
      .map(fn(s) { @util.double_from_hex(s.to_owned()) })
      .collect()
    let specifier : String? = if p[2] == "-" { None } else { Some(p[2]) }
    let f = @format.format_span(nums[0], nums[1], nums[2], specifier?) catch {
      FormatError(msg) => fail("format_span raised \{msg}")
    }
    let expected = p[3]
      .split("~")
      .map(fn(s) { unescape(s.to_owned()) })
      .collect()
    assert_eq(expected.length(), values.length())
    for i in 0..<values.length() {
      let got = f(values[i])
      if got != expected[i] {
        fail(
          "formatSpan(\{nums[0]}, \{nums[1]}, \{nums[2]}, \{p[2]})(\{values[i]}): expected \"\{expected[i]}\", got \"\{got}\"",
        )
      }
    }
  }
}

///|
test "invalid specifiers raise FormatError" {
  let ok1 = try {
    ignore(@format.format("!!"))
    true
  } catch {
    _ => false
  }
  assert_false(ok1)
  let ok2 = try {
    ignore(@format.format("."))
    true
  } catch {
    _ => false
  }
  assert_false(ok2)
  let ok3 = try {
    ignore(@format.format(",.2f"))
    true
  } catch {
    _ => false
  }
  assert_true(ok3)
}

///|
test "format examples" {
  assert_eq(must_format(",.2f")(1234.567), "1,234.57")
  assert_eq(must_format(".2f")(-5.0), "\u{2212}5.00")
  assert_eq(must_format("s")(1234.0), "1.23400k")
  assert_eq(must_format("")(0.1 + 0.2), "0.3")
}
