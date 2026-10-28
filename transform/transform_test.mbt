///|
fn parse_row(text : String) -> Map[String, @value.Value] raise {
  let j = @json.parse(@util.unescape_fixture(text))
  match @value.from_json(j) {
    Obj(m) => m
    _ => fail("row is not an object")
  }
}

///|
fn jfield(m : Map[String, @value.Value], k : String) -> @value.Value {
  match m.get(k) {
    Some(v) => v
    None => Undef
  }
}

///|
fn strs(v : @value.Value) -> Array[String] {
  match v {
    Arr(items) =>
      items.map(fn(x) {
        match x {
          Str(s) => s
          _ => ""
        }
      })
    _ => []
  }
}

///|
fn opt_strs(v : @value.Value) -> Array[String?] {
  match v {
    Arr(items) =>
      items.map(fn(x) {
        match x {
          Str(s) => Some(s)
          _ => None
        }
      })
    _ => []
  }
}

///|
fn nums_of(v : @value.Value) -> Array[Double] {
  match v {
    Arr(items) => items.map(fn(x) { x.to_number() })
    _ => []
  }
}

///|
fn num_opt(v : @value.Value) -> Double? {
  match v {
    Num(x) => Some(x)
    _ => None
  }
}

///|
fn bool_or(v : @value.Value, d : Bool) -> Bool {
  match v {
    Bool(b) => b
    _ => d
  }
}

///|
fn num_or(v : @value.Value, d : Double) -> Double {
  match v {
    Num(x) => x
    _ => d
  }
}

///|
/// Compare one output row to the expected `k=ser` fields.
fn check_row(
  id : String,
  idx : Int32,
  got : Map[String, @value.Value],
  want : Array[String],
) -> Unit raise {
  let want_keys : Array[String] = []
  for f in want {
    let eq = f.find("=").unwrap_or(-1)
    let key = @util.unescape_fixture(f.unsafe_substring(start=0, end=eq))
    let ser = f.unsafe_substring(start=eq + 1, end=f.length())
    want_keys.push(key)
    let v = match got.get(key) {
      Some(v) => v
      None => fail("\{id} row \{idx}: missing key \{key}")
    }
    let ok = if ser == "u" {
      v is Undef
    } else if ser == "z" {
      v is Null
    } else if ser.has_prefix("n:") {
      match v {
        Num(x) =>
          @util.same_bits(
            x,
            @util.double_from_hex(ser.unsafe_substring(start=2, end=18)),
          )
        _ => false
      }
    } else if ser.has_prefix("s:") {
      match v {
        Str(s) =>
          s ==
          @util.unescape_fixture(
            ser.unsafe_substring(start=2, end=ser.length()),
          )
        // objects and arrays are serialised as JSON text by the generator
        Obj(_) | Arr(_) => ser.has_prefix("s:{") || ser.has_prefix("s:[")
        _ => false
      }
    } else if ser.has_prefix("b:") {
      match v {
        Bool(b) => b == (ser == "b:1")
        _ => false
      }
    } else {
      false
    }
    if !ok {
      fail(
        "\{id} row \{idx} key \{key}: expected \{ser}, got \{v.to_js_string()} (variant check)",
      )
    }
  }
  for k, _ in got {
    if !want_keys.contains(k) {
      fail("\{id} row \{idx}: unexpected key \{k}")
    }
  }
}

///|
test "transforms match vega" {
  let lines = @util.fixture_lines(@transformcases.cases, "T")
  let ins = @util.fixture_lines(@transformcases.cases, "I")
  let outs = @util.fixture_lines(@transformcases.cases, "O")
  let exts = @util.fixture_lines(@transformcases.cases, "G")
  assert_true(lines.length() > 100)
  let mut checked = 0
  for t in lines {
    let id = t[1]
    let spec = parse_row(t[2])
    let rows : Array[Map[String, @value.Value]] = []
    for r in ins {
      if r[1] == id {
        rows.push(parse_row(r[2]))
      }
    }
    let kind = match jfield(spec, "type") {
      Str(s) => s
      _ => ""
    }
    let result : Array[Map[String, @value.Value]] = match kind {
      "aggregate" => {
        let groupby = strs(jfield(spec, "groupby"))
        let fields = match jfield(spec, "fields") {
          Arr(_) => opt_strs(jfield(spec, "fields"))
          _ => [None]
        }
        let ops = strs(jfield(spec, "ops"))
        let as_names = opt_strs(jfield(spec, "as"))
        let measures : Array[@transform.Measure] = []
        for i in 0..<ops.length() {
          let f = fields[i]
          let as_name = if i < as_names.length() { as_names[i] } else { None }
          measures.push({
            op: ops[i],
            field: f,
            out: @transform.measure_name(ops[i], f, as_name),
          })
        }
        @transform.aggregate(rows, groupby, measures)
      }
      "bin" => {
        let ext = nums_of(jfield(spec, "extent"))
        let steps = match jfield(spec, "steps") {
          Arr(_) => Some(nums_of(jfield(spec, "steps")))
          _ => None
        }
        let divide = match jfield(spec, "divide") {
          Arr(_) => nums_of(jfield(spec, "divide"))
          _ => [5.0, 2.0]
        }
        let p = @transform.BinParams::new(
          (ext[0], ext[1]),
          maxbins=num_or(jfield(spec, "maxbins"), 20.0),
          base=num_or(jfield(spec, "base"), 10.0),
          divide~,
          step?=num_opt(jfield(spec, "step")),
          steps?,
          minstep=num_or(jfield(spec, "minstep"), 0.0),
          nice=bool_or(jfield(spec, "nice"), true),
          anchor?=num_opt(jfield(spec, "anchor")),
        )
        let as_names = strs(jfield(spec, "as"))
        let field = match jfield(spec, "field") {
          Str(s) => s
          _ => ""
        }
        @transform.bin_rows(
          rows,
          field,
          p,
          as_names[0],
          as_names[1],
          interval=bool_or(jfield(spec, "interval"), true),
        )
        rows
      }
      "extent" => {
        let field = match jfield(spec, "field") {
          Str(s) => s
          _ => ""
        }
        let e = @transform.extent(rows, field)
        for g in exts {
          if g[1] == id {
            match e {
              Some((lo, hi)) => {
                assert_true(g[2] == "n:" + @util.double_to_hex(lo))
                assert_true(g[3] == "n:" + @util.double_to_hex(hi))
              }
              None => {
                assert_eq(g[2], "u")
                assert_eq(g[3], "u")
              }
            }
          }
        }
        rows
      }
      "stack" => {
        let as_names = strs(jfield(spec, "as"))
        let field = match jfield(spec, "field") {
          Str(s) => Some(s)
          _ => None
        }
        let sort = match jfield(spec, "sort") {
          Obj(m) =>
            Some(@transform.StackSort::{
              fields: strs(jfield(m, "field")),
              descending: strs(jfield(m, "order")).map(fn(o) {
                o == "descending"
              }),
            })
          _ => None
        }
        let offset = match jfield(spec, "offset") {
          Str(s) => s
          _ => "zero"
        }
        @transform.stack(
          rows,
          field,
          strs(jfield(spec, "groupby")),
          sort,
          offset,
          as_names[0],
          as_names[1],
        )
        rows
      }
      "impute" => {
        @transform.impute(
          rows,
          strs(Arr([jfield(spec, "field")]))[0],
          strs(jfield(spec, "groupby")),
          strs(Arr([jfield(spec, "key")]))[0],
          0.0,
        )
        rows
      }
      "fold" => {
        let as_names = strs(jfield(spec, "as"))
        @transform.fold(
          rows,
          strs(jfield(spec, "fields")),
          as_names[0],
          as_names[1],
        )
      }
      "timeunit" => {
        let as_names = strs(jfield(spec, "as"))
        @transform.timeunit(
          rows,
          match jfield(spec, "field") {
            Str(s) => s
            _ => ""
          },
          strs(jfield(spec, "units")),
          step=num_or(jfield(spec, "step"), 1.0).to_int(),
          as0=as_names[0],
          as1=if as_names.length() > 1 { as_names[1] } else { "unit1" },
          interval=bool_or(jfield(spec, "interval"), true),
        )
        rows
      }
      "filter" =>
        @transform.filter(
          rows,
          match jfield(spec, "expr") {
            Str(s) => s
            _ => ""
          },
        )
      "formula" => {
        @transform.formula(
          rows,
          match jfield(spec, "expr") {
            Str(s) => s
            _ => ""
          },
          match jfield(spec, "as") {
            Str(s) => s
            _ => ""
          },
        )
        rows
      }
      other => fail("unknown transform \{other}")
    }
    let want_rows : Array[Array[String]] = []
    for o in outs {
      if o[1] == id {
        want_rows.push(o)
      }
    }
    if kind != "extent" {
      if result.length() != want_rows.length() {
        fail(
          "\{id} (\{kind}): expected \{want_rows.length()} rows, got \{result.length()}",
        )
      }
      for i in 0..<result.length() {
        let w = want_rows[i]
        check_row(id, i, result[i], w[2:w.length()].to_owned())
      }
    }
    checked = checked + 1
  }
  assert_true(checked > 100)
}
