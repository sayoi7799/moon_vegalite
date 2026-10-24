///|
fn cases(kind : String) -> Array[Array[String]] {
  @util.fixture_lines(@scalecases.cases, kind)
}

///|
/// Space separated hex doubles; "u" is JavaScript `undefined`.
fn hexes(s : String) -> Array[Double?] {
  if s == "-" || s == "" {
    return []
  }
  s
  .split(" ")
  .map(fn(h) {
    let t = h.to_owned()
    if t == "u" {
      None
    } else {
      Some(@util.double_from_hex(t))
    }
  })
  .collect()
}

///|
fn nums(s : String) -> Array[Double] {
  hexes(s).map(fn(x) { x.unwrap_or(@double.not_a_number) })
}

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
  (a - b).abs() <= 1.0e-12 * scale
}

///|
fn kind_of(spec : String) -> (@scale.ScaleKind, Bool) {
  let parts = spec.split(",").map(fn(s) { s.to_owned() }).collect()
  let param = @util.double_from_hex(parts[1])
  match parts[0] {
    "linear" => (Linear, true)
    "sqrt" => (@scale.ScaleKind::sqrt(), true)
    "pow" => (Pow(param), false)
    // only base 10 uses an exactly reproducible power function
    _ => (Log(param), param == 10.0)
  }
}

///|
fn same(strict : Bool, a : Double, b : Double) -> Bool {
  if strict {
    @util.same_bits(a, b)
  } else {
    close(a, b)
  }
}

///|
test "continuous scales match vega.scale for linear, sqrt, pow and log" {
  let cs = cases("cont")
  assert_true(cs.length() > 300)
  for p in cs {
    let (kind, strict) = kind_of(p[1])
    let s = @scale.Continuous::new(kind)
    s.domain = nums(p[2])
    s.range = nums(p[3])
    let flags = p[4].split(",").map(fn(f) { f.to_owned() }).collect()
    s.clamp = flags[0] == "1"
    s.round = flags[1] == "1"
    if flags[2] != "-" {
      let c : Double = @string.from_str(flags[2])
      s.nice(count=c)
    }
    let ctx = "\{p[1]} domain=\{p[2]} range=\{p[3]} flags=\{p[4]}"
    // domain after nice
    let want_domain = nums(p[7])
    assert_eq(s.domain.length(), want_domain.length())
    for i in 0..<want_domain.length() {
      if !same(strict, s.domain[i], want_domain[i]) {
        fail(
          "domain[\{i}]: expected \{want_domain[i]}, got \{s.domain[i]} (\{ctx})",
        )
      }
    }
    // mapping
    let xs = nums(p[5])
    let ys = hexes(p[6])
    for i in 0..<xs.length() {
      match (s.map(xs[i]), ys[i]) {
        (Some(got), Some(want)) =>
          if !same(strict, got, want) {
            fail("map(\{xs[i]}): expected \{want}, got \{got} (\{ctx})")
          }
        (None, None) => ()
        _ => fail("map(\{xs[i]}) unknown mismatch (\{ctx})")
      }
    }
    // ticks for counts 2, 5, 10
    let tick_sets = p[8].split(";").map(fn(t) { t.to_owned() }).collect()
    let counts = [2.0, 5.0, 10.0]
    for k in 0..<3 {
      let want = nums(tick_sets[k])
      let got = s.ticks(count=counts[k])
      if got.length() != want.length() {
        fail(
          "ticks(\{counts[k]}) length: expected \{want.length()}, got \{got.length()} (\{ctx})",
        )
      }
      for i in 0..<want.length() {
        if !same(strict, got[i], want[i]) {
          fail(
            "ticks(\{counts[k]})[\{i}]: expected \{want[i]}, got \{got[i]} (\{ctx})",
          )
        }
      }
    }
  }
}

///|
test "band and point scales match vega" {
  let cs = cases("band")
  assert_true(cs.length() > 300)
  for p in cs {
    let s = if p[1] == "band" {
      @scale.Band::band()
    } else {
      @scale.Band::point()
    }
    let count : Int32 = @string.from_str(p[2])
    let domain : Array[@value.Value] = []
    for i in 0..<count {
      domain.push(Str("v\{i}"))
    }
    s.set_domain(domain)
    let r = nums(p[3])
    let params = p[4].split(",").map(fn(h) { h.to_owned() }).collect()
    let pi = @util.double_from_hex(params[0])
    let po = @util.double_from_hex(params[1])
    let align = @util.double_from_hex(params[2])
    if p[1] == "band" {
      s.set_padding_inner(pi)
    }
    s.set_padding_outer(po)
    s.set_align(align)
    if params[3] == "1" {
      s.set_range_round(r[0], r[1])
    } else {
      s.set_range(r[0], r[1])
    }
    let sizes = p[5]
      .split(",")
      .map(fn(h) { @util.double_from_hex(h.to_owned()) })
      .collect()
    let want = nums(p[6])
    let ctx = "\{p[1]} n=\{count} range=\{p[3]} params=\{p[4]}"
    if !@util.same_bits(s.bandwidth, sizes[0]) {
      fail("bandwidth: expected \{sizes[0]}, got \{s.bandwidth} (\{ctx})")
    }
    if !@util.same_bits(s.step, sizes[1]) {
      fail("step: expected \{sizes[1]}, got \{s.step} (\{ctx})")
    }
    for i in 0..<count {
      match s.map(domain[i]) {
        Some(got) =>
          if !@util.same_bits(got, want[i]) {
            fail("position[\{i}]: expected \{want[i]}, got \{got} (\{ctx})")
          }
        None => fail("position[\{i}] missing (\{ctx})")
      }
    }
  }
}

///|
test "ordinal scales match vega" {
  for p in cases("ordinal") {
    let names = fn(s : String) {
      if s == "-" {
        []
      } else {
        s
        .split(" ")
        .map(fn(x) { @value.Value::Str(@util.unescape_fixture(x.to_owned())) })
        .collect()
      }
    }
    let s = @scale.Ordinal::new()
    s.set_domain(names(p[1]))
    s.set_range(names(p[2]))
    let probe = names(p[3])
    let want = p[4].split(" ").map(fn(x) { x.to_owned() }).collect()
    for i in 0..<probe.length() {
      let got = match s.map(probe[i]) {
        Some(Str(v)) => v
        Some(_) => "?"
        None => "u"
      }
      if got != want[i] {
        fail("ordinal(\{p[3]})[\{i}]: expected \{want[i]}, got \{got}")
      }
    }
  }
}

///|
fn scheme_interpolator(name : String) -> ((Double) -> String) raise {
  match @scale.scheme(name) {
    Some(Interpolating(f)) => f
    _ => fail("not an interpolating scheme: \{name}")
  }
}

///|
test "colour scheme interpolators match vega.scheme" {
  for p in cases("scheme") {
    let f = scheme_interpolator(p[1])
    let ts = nums(p[2])
    let want = p[3].split(" ").map(fn(x) { x.to_owned() }).collect()
    // rgb(r, g, b) strings contain spaces: re-join them in groups of three tokens
    let joined : Array[String] = []
    let mut i = 0
    while i + 2 < want.length() {
      joined.push(want[i] + " " + want[i + 1] + " " + want[i + 2])
      i = i + 3
    }
    assert_eq(joined.length(), ts.length())
    for k in 0..<ts.length() {
      let got = f(ts[k])
      if got != joined[k] {
        fail("scheme(\{p[1]})(\{ts[k]}): expected \{joined[k]}, got \{got}")
      }
    }
  }
}

///|
test "sequential scales match vega" {
  for p in cases("seq") {
    let f = scheme_interpolator(p[1])
    let s = @scale.Sequential::new(Linear, f)
    s.scale.domain = nums(p[2])
    s.scale.clamp = p[3] == "1"
    let xs = nums(p[4])
    let want = p[5].split(" ").map(fn(x) { x.to_owned() }).collect()
    for i in 0..<xs.length() {
      let got = s.map(xs[i]).unwrap_or("u")
      let w = want[3 * i] + " " + want[3 * i + 1] + " " + want[3 * i + 2]
      if got != w {
        fail(
          "sequential(\{p[1]}, \{p[2]})(\{xs[i]}): expected \{w}, got \{got}",
        )
      }
    }
  }
}

///|
test "quantized ordinal ramps match vega" {
  for p in cases("quant") {
    let f = scheme_interpolator(p[1])
    let count : Int32 = @string.from_str(p[2])
    let got = @scale.quantize_interpolator(f, count)
    let want = p[3].split(" ").map(fn(x) { x.to_owned() }).collect()
    assert_eq(got.length(), count)
    for i in 0..<count {
      let w = want[3 * i] + " " + want[3 * i + 1] + " " + want[3 * i + 2]
      assert_eq(got[i], w)
    }
  }
}

///|
test "discrete schemes and colour parsing" {
  match @scale.scheme("Tableau10") {
    Some(Discrete(colors)) => {
      assert_eq(colors.length(), 10)
      assert_eq(colors[0], "#4c78a8")
    }
    _ => fail("tableau10 missing")
  }
  assert_true(@scale.scheme("nope") is None)
  match @scale.parse_color("steelblue") {
    Some(c) => assert_eq(c.format_rgb(), "rgb(70, 130, 180)")
    None => fail("steelblue")
  }
  match @scale.parse_color("#f00") {
    Some(c) => assert_eq(c.format_rgb(), "rgb(255, 0, 0)")
    None => fail("#f00")
  }
  match @scale.parse_color("rgba(10, 20, 30, 0.5)") {
    Some(c) => assert_eq(c.format_rgb(), "rgba(10, 20, 30, 0.5)")
    None => fail("rgba")
  }
  assert_true(@scale.parse_color("not-a-color") is None)
}
