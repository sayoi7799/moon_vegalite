// Ports of vega-transforms 5.x `Aggregate`, `Extent` and `Bin`
// (BSD-3-Clause) and the supporting vega-statistics routines.

///|
/// One aggregate measure: `op` over `field` (None for a plain `count`),
/// written to the output field `out`.
pub(all) struct Measure {
  op : String
  field : String?
  out : String
}

///|
/// vega's default output name of a measure.
pub fn measure_name(op : String, field : String?, as_name : String?) -> String {
  match as_name {
    Some(n) => n
    None =>
      match field {
        Some(f) => op + "_" + f
        None => op
      }
  }
}

///|
fn op_index(op : String) -> Int32 {
  match op {
    "values" => -1
    "average" | "variance" => 1
    "variancep" | "stdev" | "stdevp" | "stderr" => 2
    "distinct" | "ci0" | "ci1" | "median" | "q1" | "q3" | "argmin" | "argmax" =>
      3
    "min" | "max" => 4
    _ => 0
  }
}

///|
/// d3-array `quantileSorted` on an ascending array of numbers.
pub fn quantile_sorted(values : Array[Double], p : Double) -> Double? {
  let n = values.length()
  if n == 0 || p.is_nan() {
    return None
  }
  if p <= 0.0 || n < 2 {
    return Some(values[0])
  }
  if p >= 1.0 {
    return Some(values[n - 1])
  }
  let i = (n - 1).to_double() * p
  let i0 = i.floor()
  let v0 = values[i0.to_int()]
  let v1 = values[i0.to_int() + 1]
  Some(v0 + (v1 - v0) * (i - i0))
}

///|
/// vega-statistics `numbers(values)`: the numeric values, skipping null, ''
/// and NaN.
pub fn numbers_of(values : Array[@value.Value]) -> Array[Double] {
  let out : Array[Double] = []
  for v in values {
    match v {
      Null | Undef | Str("") => ()
      other => {
        let x = other.to_number()
        if x >= x {
          out.push(x)
        }
      }
    }
  }
  out
}

///|
fn sort_numbers(a : Array[Double]) -> Unit {
  a.sort_by(fn(x, y) { if x < y { -1 } else if x > y { 1 } else { 0 } })
}

///|
priv struct Acc {
  field : String
  ops : Array[(String, String)]
  mut valid : Int32
  mut missing : Int32
  mut sum : Double
  mut mean : Double
  mut mean_d : Double
  mut dev : Double
  mut min : @value.Value
  mut max : @value.Value
  values : Array[@value.Value]
}

///|
priv struct Cell {
  tuple : Map[String, @value.Value]
  mut num : Int32
  accs : Array[Acc]
}

///|
fn Acc::add(self : Acc, v : @value.Value) -> Unit {
  self.values.push(v)
  match v {
    Null | Undef | Str("") => {
      self.missing = self.missing + 1
      return
    }
    Num(x) if x.is_nan() => return
    _ => ()
  }
  self.valid = self.valid + 1
  let x = v.to_number()
  self.sum = self.sum + x
  self.mean_d = x - self.mean
  self.mean = self.mean + self.mean_d / self.valid.to_double()
  self.dev = self.dev + self.mean_d * (x - self.mean)
  if self.min is Undef || @expr.js_less(v, self.min) {
    self.min = v
  }
  if self.max is Undef || @expr.js_less(self.max, v) {
    self.max = v
  }
}

///|
fn Acc::value(self : Acc, op : String) -> @value.Value {
  let valid = self.valid.to_double()
  match op {
    "valid" => Num(valid)
    "missing" => Num(self.missing.to_double())
    "sum" => if self.valid > 0 { Num(self.sum) } else { Undef }
    "mean" | "average" => if self.valid > 0 { Num(self.mean) } else { Undef }
    "variance" =>
      if self.valid > 1 {
        Num(self.dev / (valid - 1.0))
      } else {
        Undef
      }
    "variancep" => if self.valid > 1 { Num(self.dev / valid) } else { Undef }
    "stdev" =>
      if self.valid > 1 {
        Num((self.dev / (valid - 1.0)).sqrt())
      } else {
        Undef
      }
    "stdevp" =>
      if self.valid > 1 {
        Num((self.dev / valid).sqrt())
      } else {
        Undef
      }
    "stderr" =>
      if self.valid > 1 {
        Num((self.dev / (valid * (valid - 1.0))).sqrt())
      } else {
        Undef
      }
    "min" => self.min
    "max" => self.max
    "distinct" => {
      let seen : Map[String, Bool] = Map([])
      for v in self.values {
        seen[v.to_js_string()] = true
      }
      Num(seen.length().to_double())
    }
    "median" | "q1" | "q3" => {
      let nums = numbers_of(self.values)
      sort_numbers(nums)
      let p = if op == "median" {
        0.5
      } else if op == "q1" {
        0.25
      } else {
        0.75
      }
      match quantile_sorted(nums, p) {
        Some(q) => Num(q)
        None => Undef
      }
    }
    _ => Undef
  }
}

///|
/// Operators supported by `aggregate`.
pub fn is_aggregate_op(op : String) -> Bool {
  match op {
    "count"
    | "valid"
    | "missing"
    | "sum"
    | "mean"
    | "average"
    | "variance"
    | "variancep"
    | "stdev"
    | "stdevp"
    | "stderr"
    | "distinct"
    | "median"
    | "q1"
    | "q3"
    | "min"
    | "max" => true
    _ => false
  }
}

///|
/// Group-by aggregation with vega's semantics: groups appear in order of
/// first occurrence, `count` counts all tuples, the other measures skip null,
/// '' and NaN, and the mean is accumulated incrementally.
pub fn aggregate(
  rows : Array[Map[String, @value.Value]],
  groupby : Array[String],
  measures : Array[Measure],
) -> Array[Map[String, @value.Value]] raise TransformError {
  // measures grouped by input field, in order of first appearance
  let field_order : Array[String] = []
  let counts : Array[String] = []
  let by_field : Map[String, Array[(String, String)]] = Map([])
  for m in measures {
    if !is_aggregate_op(m.op) {
      raise TransformError("Unsupported aggregate operation: " + m.op)
    }
    if m.op == "count" {
      counts.push(m.out)
      continue
    }
    match m.field {
      None => raise TransformError("Null aggregate field specified.")
      Some(f) => {
        if !by_field.contains(f) {
          by_field[f] = []
          field_order.push(f)
        }
        by_field[f].push((m.op, m.out))
      }
    }
  }
  let cells : Array[Cell] = []
  let index : Map[String, Int32] = Map([])
  for t in rows {
    let key = if groupby.length() == 0 {
      ""
    } else {
      groupby.map(fn(g) { @value.get_field(t, g).to_js_string() }).join("|")
    }
    let ci = match index.get(key) {
      Some(i) => i
      None => {
        let tuple : Map[String, @value.Value] = Map([])
        for g in groupby {
          tuple[g] = @value.get_field(t, g)
        }
        let accs = field_order.map(fn(f) {
          let ops = by_field[f].copy()
          ops.sort_by(fn(a, b) { op_index(a.0) - op_index(b.0) })
          {
            field: f,
            ops,
            valid: 0,
            missing: 0,
            sum: 0.0,
            mean: 0.0,
            mean_d: 0.0,
            dev: 0.0,
            min: Undef,
            max: Undef,
            values: [],
          }
        })
        cells.push({ tuple, num: 0, accs, })
        index[key] = cells.length() - 1
        cells.length() - 1
      }
    }
    let cell = cells[ci]
    cell.num = cell.num + 1
    for acc in cell.accs {
      acc.add(@value.get_field(t, acc.field))
    }
  }
  let out : Array[Map[String, @value.Value]] = []
  for cell in cells {
    let tuple = cell.tuple
    for c in counts {
      tuple[c] = Num(cell.num.to_double())
    }
    for acc in cell.accs {
      for pair in acc.ops {
        tuple[pair.1] = acc.value(pair.0)
      }
    }
    out.push(tuple)
  }
  out
}

///|
/// vega `Extent`: [min, max] over the numeric values of a field, None when
/// there is no finite extent.
pub fn extent(
  rows : Array[Map[String, @value.Value]],
  field : String,
) -> (Double, Double)? {
  let mut lo = @double.infinity
  let mut hi = @double.neg_infinity
  for t in rows {
    match @value.get_field(t, field).coerce_number() {
      Num(x) => {
        if x < lo {
          lo = x
        }
        if x > hi {
          hi = x
        }
      }
      _ => ()
    }
  }
  if lo.is_inf() || hi.is_inf() || lo.is_nan() || hi.is_nan() {
    None
  } else {
    Some((lo, hi))
  }
}
