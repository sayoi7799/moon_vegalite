///|
fn cases(kind : String) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for line in @ticks.cases.split("\n") {
    let parts = line.split(" ").map(fn(s) { s.to_owned() }).collect()
    if parts[0] == kind {
      out.push(parts)
    }
  }
  out
}

///|
fn fmt_list(xs : Array[Double]) -> String {
  if xs.length() == 0 {
    "-"
  } else {
    xs.map(@util.double_to_hex).join(",")
  }
}

///|
test "ticks matches d3-array" {
  let cs = cases("ticks")
  assert_true(cs.length() > 1000)
  for p in cs {
    let a = @util.double_from_hex(p[1])
    let b = @util.double_from_hex(p[2])
    let c = @util.double_from_hex(p[3])
    let got = fmt_list(@stats.ticks(a, b, c))
    if got != p[4] {
      fail(
        "ticks(\{a}, \{b}, \{c}) [\{p[1]} \{p[2]} \{p[3]}]: expected \{p[4]}, got \{got}",
      )
    }
  }
}

///|
test "tick_increment matches d3-array" {
  for p in cases("inc") {
    let a = @util.double_from_hex(p[1])
    let b = @util.double_from_hex(p[2])
    let c = @util.double_from_hex(p[3])
    let got = @util.double_to_hex(@stats.tick_increment(a, b, c))
    if got != p[4] {
      fail("tickIncrement(\{a}, \{b}, \{c}): expected \{p[4]}, got \{got}")
    }
  }
}

///|
test "tick_step matches d3-array" {
  for p in cases("step") {
    let a = @util.double_from_hex(p[1])
    let b = @util.double_from_hex(p[2])
    let c = @util.double_from_hex(p[3])
    let got = @util.double_to_hex(@stats.tick_step(a, b, c))
    if got != p[4] {
      fail("tickStep(\{a}, \{b}, \{c}): expected \{p[4]}, got \{got}")
    }
  }
}

///|
test "ticks examples" {
  assert_eq(@stats.ticks(0.0, 10.0, 5.0), [0.0, 2.0, 4.0, 6.0, 8.0, 10.0])
  assert_eq(@stats.ticks(10.0, 0.0, 5.0), [10.0, 8.0, 6.0, 4.0, 2.0, 0.0])
  assert_eq(@stats.ticks(1.0, 1.0, 5.0), [1.0])
  assert_eq(@stats.ticks(0.0, 1.0, 0.0), [])
}
