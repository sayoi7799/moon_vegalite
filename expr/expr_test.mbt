///|
fn close(a : Double, b : Double) -> Bool {
  if @util.same_bits(a, b) {
    return true
  }
  if a.is_nan() || b.is_nan() {
    return false
  }
  if a.is_inf() || b.is_inf() {
    return a == b
  }
  let scale = if b.abs() > 1.0 { b.abs() } else { 1.0 }
  (a - b).abs() <= 1.0e-13 * scale
}

///|
test "expressions match vega's expression engine" {
  let rows : Array[@value.Value] = []
  for p in @util.fixture_lines(@exprcases.cases, "row") {
    let j = @json.parse(@util.unescape_fixture(p[1])) catch {
      _ => fail("bad row json")
    }
    rows.push(@value.from_json(j))
  }
  assert_eq(rows.length(), 7)
  let cs = @util.fixture_lines(@exprcases.cases, "expr")
  assert_true(cs.length() > 200)
  let mut compared = 0
  for p in cs {
    let src = @util.unescape_fixture(p[1])
    let ast = @expr.parse_expr(src) catch {
      @expr.ExprError(msg) => fail("parse failed for \{src}: \{msg}")
    }
    for i in 0..<rows.length() {
      let want = p[2 + i]
      if want == "E" {
        continue
      }
      let got = @expr.eval_expr(ast, rows[i]) catch {
        @expr.ExprError(msg) =>
          fail("eval failed for \{src} on row \{i}: \{msg}")
      }
      let ctx = "\{src} on row \{i}"
      if want == "z" {
        if !(got is Null || got is Undef) {
          fail("\{ctx}: expected null/undefined, got \{got.to_js_string()}")
        }
      } else if want.has_prefix("n:") {
        match got {
          Num(x) =>
            if !close(
                x,
                @util.double_from_hex(want.unsafe_substring(start=2, end=18)),
              ) {
              fail(
                "\{ctx}: expected \{@util.double_from_hex(want.unsafe_substring(start=2, end=18))}, got \{x}",
              )
            }
          other =>
            fail("\{ctx}: expected a number, got \{other.to_js_string()}")
        }
      } else if want.has_prefix("s:") {
        let w = @util.unescape_fixture(
          want.unsafe_substring(start=2, end=want.length()),
        )
        match got {
          Str(s) =>
            if s != w {
              fail("\{ctx}: expected \"\{w}\", got \"\{s}\"")
            }
          other =>
            fail("\{ctx}: expected a string, got \{other.to_js_string()}")
        }
      } else if want.has_prefix("b:") {
        let w = want == "b:1"
        match got {
          Bool(b) => if b != w { fail("\{ctx}: expected \{w}, got \{b}") }
          other =>
            fail("\{ctx}: expected a boolean, got \{other.to_js_string()}")
        }
      }
      compared = compared + 1
    }
  }
  assert_true(compared > 1500)
}

///|
test "unsupported syntax is rejected with a message" {
  let bad = [
    "[1, 2]", "{a: 1}", "foo(1)", "random()", "datum.x +", "signalName + 1", "now()",
    "regexp('a')", "scale('x', 1)", "1 +* 2", "'unterminated", "max(1,",
  ]
  for src in bad {
    let ok = try {
      ignore(@expr.parse_expr(src))
      true
    } catch {
      _ => false
    }
    if ok {
      fail("expected a parse error for \{src}")
    }
  }
}

///|
test "lazy conditionals and logical operators return operands" {
  let datum = @value.Value::Obj(Map([("a", @value.Value::Num(0.0))]))
  let run = fn(src : String) raise {
    let ast = @expr.parse_expr(src) catch { _ => fail("parse") }
    @expr.eval_expr(ast, datum) catch {
      _ => fail("eval")
    }
  }
  assert_true(run("datum.a || 'x'") is Str("x"))
  assert_true(run("datum.a && 1") is Num(0.0))
  assert_true(run("if(datum.a, 1, 2)") is Num(2.0))
  assert_true(run("datum.a == 0 ? 'zero' : 'other'") is Str("zero"))
}
