///|
fn cases(kind : String) -> Array[Array[String]] {
  let out : Array[Array[String]] = []
  for line in @timecases.cases.split("\n") {
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
fn num(s : String) -> Double {
  if s == "NaN" {
    @double.not_a_number
  } else {
    @string.from_str(s) catch {
      _ => @double.not_a_number
    }
  }
}

///|
fn nums(s : String) -> Array[Double] {
  if s == "-" {
    []
  } else {
    s.split(",").map(fn(x) { num(x.to_owned()) }).collect()
  }
}

///|
fn show(x : Double) -> String {
  if x.is_nan() {
    "NaN"
  } else {
    @util.js_number_to_string(x)
  }
}

///|
fn show_list(xs : Array[Double]) -> String {
  if xs.length() == 0 {
    "-"
  } else {
    xs.map(show).join(",")
  }
}

///|
test "utc_parts matches JavaScript Date getUTC*" {
  let cs = cases("parts")
  assert_true(cs.length() > 300)
  for p in cs {
    let t = num(p[1])
    let q = @time.utc_parts(t)
    let got = [
        q.year,
        q.month,
        q.date,
        q.day,
        q.hours,
        q.minutes,
        q.seconds,
        q.millis,
      ]
      .map(fn(v) { v.to_string() })
      .join(",")
    if got != p[2] {
      fail("utc_parts(\{p[1]}): expected \{p[2]}, got \{got}")
    }
  }
}

///|
test "utc_ms matches Date.UTC" {
  for p in cases("utcms") {
    let a = nums(p[1])
    let got = show(@time.utc_ms(a[0], a[1], a[2], a[3], a[4], a[5], a[6]))
    if got != p[2] {
      fail("Date.UTC(\{p[1]}): expected \{p[2]}, got \{got}")
    }
  }
}

///|
fn interval_of(name : String) -> @time.TimeInterval raise {
  let (unit, every) = match name.find("/") {
    Some(i) =>
      (
        name.unsafe_substring(start=0, end=i),
        Some(
          (
            @string.from_str(
              name.unsafe_substring(start=i + 1, end=name.length()),
            ) : Double),
        ),
      )
    None => (name, None)
  }
  let base = match @time.utc_interval(unit) {
    Some(iv) => iv
    None => fail("unknown unit \{unit}")
  }
  match every {
    None => base
    Some(k) =>
      match base.every(k) {
        Some(iv) => iv
        None => fail("no every(\{k}) for \{unit}")
      }
  }
}

///|
test "intervals match vega-time utcInterval" {
  let cs = cases("ival")
  assert_true(cs.length() > 1000)
  for p in cs {
    let iv = interval_of(p[1])
    let a = nums(p[3])
    let got = match p[2] {
      "floor" => show(iv.floor(a[0]))
      "ceil" => show(iv.ceil(a[0]))
      "offset" => show(iv.offset(a[0], a[1].to_int()))
      "count" =>
        match iv.count(a[0], a[1]) {
          Some(c) => show(c)
          None => "no-count"
        }
      "range" => show_list(iv.range(a[0], a[1], step=a[2].to_int()))
      op => fail("unknown op \{op}")
    }
    if got != p[4] {
      fail("\{p[1]}.\{p[2]}(\{p[3]}): expected \{p[4]}, got \{got}")
    }
  }
}

///|
test "utc time scale ticks, labels and nice match vega" {
  let multi = @time.utc_multi_format()
  let tcs = cases("ticks")
  assert_true(tcs.length() > 100)
  for p in tcs {
    let a = nums(p[1])
    let got = show_list(@time.utc_ticks(a[0], a[1], a[2]))
    if got != p[2] {
      fail("ticks(\{p[1]}): expected \{p[2]}, got \{got}")
    }
  }
  for p in cases("labels") {
    let a = nums(p[1])
    let got = @time.utc_ticks(a[0], a[1], a[2]).map(multi).join("~")
    if got != p[2] {
      fail("labels(\{p[1]}): expected \{p[2]}, got \{got}")
    }
  }
  for p in cases("nice") {
    let a = nums(p[1])
    let (d0, d1) = @time.utc_nice(a[0], a[1], a[2])
    let got = show_list([d0, d1])
    if got != p[2] {
      fail("nice(\{p[1]}): expected \{p[2]}, got \{got}")
    }
  }
}

///|
test "utc_format matches d3-time-format" {
  let cs = cases("fmt")
  assert_true(cs.length() > 1000)
  for p in cs {
    let f = @time.utc_format(p[1])
    let got = f(num(p[2]))
    if got != p[3] {
      fail(
        "utcFormat(\"\{p[1]}\")(\{p[2]}): expected \"\{p[3]}\", got \"\{got}\"",
      )
    }
  }
}

///|
test "utc_parse matches d3-time-format" {
  let cs = cases("parse")
  assert_true(cs.length() > 50)
  for p in cs {
    let f = @time.utc_parse(p[1])
    let got = match f(p[2]) {
      Some(t) => show(t)
      None => "null"
    }
    if got != p[3] {
      fail("utcParse(\"\{p[1]}\")(\"\{p[2]}\"): expected \{p[3]}, got \{got}")
    }
  }
}

///|
test "utc_floor matches vega-time utcFloor" {
  let cs = cases("floor")
  assert_true(cs.length() > 1000)
  for p in cs {
    let units = p[1].split("+").map(fn(s) { s.to_owned() }).collect()
    let step : Int32 = @string.from_str(p[2])
    let f = @time.utc_floor(units, step~)
    let got = show(f(num(p[3])))
    if got != p[4] {
      fail("utcFloor(\{p[1]}, \{step})(\{p[3]}): expected \{p[4]}, got \{got}")
    }
  }
}

///|
test "time_units validates and sorts" {
  assert_eq(@time.time_units(["month", "year"]), ["year", "month"])
  let r1 = try {
    ignore(@time.time_units([]))
    true
  } catch {
    _ => false
  }
  assert_false(r1)
  let r2 = try {
    ignore(@time.time_units(["week", "month"]))
    true
  } catch {
    _ => false
  }
  assert_false(r2)
  let r3 = try {
    ignore(@time.time_units(["fortnight"]))
    true
  } catch {
    _ => false
  }
  assert_false(r3)
}
