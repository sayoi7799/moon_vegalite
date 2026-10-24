///|
test "string_to_number matches JavaScript Number(string)" {
  let cs = @util.fixture_lines(@valuecases.cases, "tonum")
  assert_true(cs.length() > 50)
  for p in cs {
    let s = @util.unescape_fixture(p[1])
    let expected = @util.double_from_hex(p[2])
    let got = @value.string_to_number(s)
    if !@util.same_bits(got, expected) {
      fail(
        "Number(\"\{p[1]}\"): expected \{@util.double_to_hex(expected)}, got \{@util.double_to_hex(got)}",
      )
    }
  }
}

///|
test "parse_date matches Date.parse for supported formats" {
  let cs = @util.fixture_lines(@valuecases.cases, "todate")
  assert_true(cs.length() > 300)
  let bad : Array[String] = []
  for p in cs {
    let s = @util.unescape_fixture(p[1])
    let expected = @util.double_from_hex(p[2])
    let got = @value.parse_date(s)
    if !@util.same_bits(got, expected) {
      bad.push(
        "\"\{p[1]}\": expected \{@util.double_to_hex(expected)} (\{expected}), got \{@util.double_to_hex(got)} (\{got})",
      )
    }
  }
  if bad.length() > 0 {
    fail("\{bad.length()} mismatches:\n" + bad.join("\n"))
  }
}

///|
test "vega-util coercions" {
  assert_true(@value.Value::Str("").coerce_number() is Null)
  assert_true(@value.Value::Null.coerce_string() is Null)
  assert_true(@value.Value::Str("3.5").coerce_number() is Num(3.5))
  assert_true(@value.Value::Str("false").coerce_boolean() is Bool(false))
  assert_true(@value.Value::Str("0").coerce_boolean() is Bool(false))
  assert_true(@value.Value::Str("x").coerce_boolean() is Bool(true))
  assert_true(@value.Value::Num(0.0).coerce_boolean() is Bool(false))
  assert_true(@value.Value::Num(12.0).coerce_date() is Num(12.0))
  match @value.Value::Str("2000-01-01").coerce_date() {
    Num(t) => assert_eq(t, 946684800000.0)
    _ => fail("expected a number")
  }
  assert_eq(@value.Value::Num(1.0e21).to_js_string(), "1e+21")
  assert_false(@value.Value::Num(@double.not_a_number).is_valid())
  assert_false(@value.Value::Null.is_valid())
  assert_true(@value.Value::Str("").is_valid())
}

///|
test "compare_values orders like vega-util ascending" {
  assert_eq(@value.compare_values(Null, Num(1.0)), -1)
  assert_eq(@value.compare_values(Num(1.0), Null), 1)
  assert_eq(@value.compare_values(Num(1.0), Num(2.0)), -1)
  assert_eq(@value.compare_values(Str("b"), Str("a")), 1)
  assert_eq(@value.compare_values(Str("a"), Str("a")), 0)
  assert_eq(@value.compare_values(Num(@double.not_a_number), Num(1.0)), -1)
  assert_eq(@value.compare_values(Bool(false), Bool(true)), -1)
}

///|
test "Map keeps insertion order" {
  let m : Map[String, @value.Value] = Map([])
  m["zeta"] = Null
  m["alpha"] = Null
  m["mid"] = Null
  assert_eq(m.keys().collect(), ["zeta", "alpha", "mid"])
}
