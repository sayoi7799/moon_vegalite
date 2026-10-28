// vega-transforms `Fold`, `Formula`, `Filter`, `TimeUnit` and vega-encode
// `Stack` (BSD-3-Clause), operating on arrays of rows.

///|
/// A stable sort (merge sort) with a comparator returning <0, 0 or >0.
pub fn[T] stable_sort(a : Array[T], cmp : (T, T) -> Int32) -> Array[T] {
  let n = a.length()
  if n < 2 {
    return a.copy()
  }
  let mid = n / 2
  let left = stable_sort(a[0:mid].to_owned(), cmp)
  let right = stable_sort(a[mid:n].to_owned(), cmp)
  let out : Array[T] = []
  let mut i = 0
  let mut j = 0
  while i < left.length() && j < right.length() {
    if cmp(right[j], left[i]) < 0 {
      out.push(right[j])
      j = j + 1
    } else {
      out.push(left[i])
      i = i + 1
    }
  }
  while i < left.length() {
    out.push(left[i])
    i = i + 1
  }
  while j < right.length() {
    out.push(right[j])
    j = j + 1
  }
  out
}

///|
/// vega `Fold`: one output row per row and folded field, carrying the field
/// name under `as0` and its value under `as1`.
pub fn fold(
  rows : Array[Map[String, @value.Value]],
  fields : Array[String],
  as0 : String,
  as1 : String,
) -> Array[Map[String, @value.Value]] {
  let out : Array[Map[String, @value.Value]] = []
  for t in rows {
    for f in fields {
      let d : Map[String, @value.Value] = Map([])
      for k, v in t {
        d[k] = v
      }
      d[as0] = Str(f)
      d[as1] = @value.get_field(t, f)
      out.push(d)
    }
  }
  out
}

///|
/// vega `Formula`: set `as_name` to the value of an expression for each row.
pub fn formula(
  rows : Array[Map[String, @value.Value]],
  src : String,
  as_name : String,
) -> Unit raise TransformError {
  let ast = @expr.parse_expr(src) catch {
    @expr.ExprError(msg) => raise TransformError(msg)
  }
  for t in rows {
    t[as_name] = @expr.eval_expr(ast, Obj(t)) catch {
      @expr.ExprError(msg) => raise TransformError(msg)
    }
  }
}

///|
/// vega `Filter`: keep the rows for which the expression is truthy.
pub fn filter(
  rows : Array[Map[String, @value.Value]],
  src : String,
) -> Array[Map[String, @value.Value]] raise TransformError {
  let ast = @expr.parse_expr(src) catch {
    @expr.ExprError(msg) => raise TransformError(msg)
  }
  let out : Array[Map[String, @value.Value]] = []
  for t in rows {
    let keep = @expr.eval_expr(ast, Obj(t)) catch {
      @expr.ExprError(msg) => raise TransformError(msg)
    }
    if keep.truthy() {
      out.push(t)
    }
  }
  out
}

///|
/// vega `TimeUnit` (UTC): floor a date field to `units` and, with `interval`,
/// also write the end of the interval.
pub fn timeunit(
  rows : Array[Map[String, @value.Value]],
  field : String,
  units : Array[String],
  step~ : Int32 = 1,
  as0~ : String = "unit0",
  as1~ : String = "unit1",
  interval~ : Bool = true,
) -> Unit raise TransformError {
  let sorted = @time.time_units(units) catch {
    @time.TimeError(msg) => raise TransformError(msg)
  }
  let floor = @time.utc_floor(sorted, step~) catch {
    @time.TimeError(msg) => raise TransformError(msg)
  }
  let unit = sorted[sorted.length() - 1]
  let iv = match @time.utc_interval(unit) {
    Some(i) => i
    None => raise TransformError("Invalid time unit: " + unit)
  }
  for t in rows {
    let v = @value.get_field(t, field)
    match v {
      Null | Undef => {
        t[as0] = Null
        if interval {
          t[as1] = Null
        }
      }
      _ => {
        let a = floor(v.to_number())
        t[as0] = Num(a)
        if interval {
          t[as1] = Num(iv.offset(a, step))
        }
      }
    }
  }
}

// ---- stack ----

///|
/// A stack sort order: compare rows by the given fields, each ascending or
/// descending (vega-util `compare(fields, orders)`).
pub(all) struct StackSort {
  fields : Array[String]
  descending : Array[Bool]
}

///|
fn compare_rows(
  sort : StackSort,
  a : Map[String, @value.Value],
  b : Map[String, @value.Value],
) -> Int32 {
  for i in 0..<sort.fields.length() {
    let c = @value.compare_values(
      @value.get_field(a, sort.fields[i]),
      @value.get_field(b, sort.fields[i]),
    )
    if c != 0 {
      return if sort.descending[i] { -c } else { c }
    }
  }
  0
}

///|
fn abs_field(t : Map[String, @value.Value], field : String?) -> Double {
  match field {
    None => 1.0
    Some(f) => @value.get_field(t, f).to_number().abs()
  }
}

///|
/// vega `Stack`: lay out `field` values in stacks per group. `offset` is
/// "zero", "center" or "normalize"; results go to `as0` / `as1`.
pub fn stack(
  rows : Array[Map[String, @value.Value]],
  field : String?,
  groupby : Array[String],
  sort : StackSort?,
  offset : String,
  as0 : String,
  as1 : String,
) -> Unit {
  let groups : Array[Array[Map[String, @value.Value]]] = []
  let index : Map[String, Int32] = Map([])
  for t in rows {
    let key = groupby
      .map(fn(g) {
        match @value.get_field(t, g) {
          Null | Undef => ""
          v => v.to_js_string()
        }
      })
      .join(",")
    match index.get(key) {
      Some(i) => groups[i].push(t)
      None => {
        index[key] = groups.length()
        groups.push([t])
      }
    }
  }
  let sums : Array[Double] = []
  let mut max = 0.0
  for gi in 0..<groups.length() {
    let mut s = 0.0
    for t in groups[gi] {
      s = s + abs_field(t, field)
    }
    sums.push(s)
    if s > max {
      max = s
    }
    match sort {
      Some(so) =>
        groups[gi] = stable_sort(groups[gi], fn(a, b) { compare_rows(so, a, b) })
      None => ()
    }
  }
  for gi in 0..<groups.length() {
    let g = groups[gi]
    match offset {
      "center" => {
        let mut last = (max - sums[gi]) / 2.0
        for t in g {
          t[as0] = Num(last)
          last = last + abs_field(t, field)
          t[as1] = Num(last)
        }
      }
      "normalize" => {
        let scale = 1.0 / sums[gi]
        let mut last = 0.0
        let mut v = 0.0
        for t in g {
          t[as0] = Num(last)
          v = v + abs_field(t, field)
          last = scale * v
          t[as1] = Num(last)
        }
      }
      _ => {
        let mut last_pos = 0.0
        let mut last_neg = 0.0
        for t in g {
          let v = match field {
            None => 1.0
            Some(f) => @value.get_field(t, f).to_number()
          }
          if v < 0.0 {
            t[as0] = Num(last_neg)
            last_neg = last_neg + v
            t[as1] = Num(last_neg)
          } else {
            t[as0] = Num(last_pos)
            last_pos = last_pos + v
            t[as1] = Num(last_pos)
          }
        }
      }
    }
  }
}

///|
/// vega `Impute` with method "value": every group (rows sharing the `groupby`
/// values) gets a row for each `key` value it lacks, with `field` set to
/// `value`. The new rows are appended after the existing ones, groups in order
/// of first appearance and keys in the order they were first seen.
pub fn impute(
  rows : Array[Map[String, @value.Value]],
  field : String,
  groupby : Array[String],
  key : String,
  value : Double,
) -> Unit {
  let domain : Array[@value.Value] = []
  let key_index : Map[String, Int32] = Map([])
  let groups : Array[(Array[@value.Value], Map[Int32, Bool])] = []
  let group_index : Map[String, Int32] = Map([])
  for t in rows {
    let k = @value.get_field(t, key)
    let ks = k.to_js_string()
    let j = match key_index.get(ks) {
      Some(j) => j
      None => {
        key_index[ks] = domain.length()
        domain.push(k)
        domain.length() - 1
      }
    }
    let gvals = groupby.map(fn(g) { @value.get_field(t, g) })
    let gkey = gvals
      .map(fn(v) {
        match v {
          Null | Undef => ""
          v => v.to_js_string()
        }
      })
      .join(",")
    match group_index.get(gkey) {
      Some(i) => groups[i].1[j] = true
      None => {
        group_index[gkey] = groups.length()
        let seen : Map[Int32, Bool] = Map([])
        seen[j] = true
        groups.push((gvals, seen))
      }
    }
  }
  let added : Array[Map[String, @value.Value]] = []
  for g in groups {
    let (gvals, seen) = g
    for j in 0..<domain.length() {
      if seen.contains(j) {
        continue
      }
      let t : Map[String, @value.Value] = Map([])
      t["_impute"] = Bool(true)
      for i in 0..<groupby.length() {
        t[groupby[i]] = gvals[i]
      }
      t[key] = domain[j]
      t[field] = Num(value)
      added.push(t)
    }
  }
  for t in added {
    rows.push(t)
  }
}
