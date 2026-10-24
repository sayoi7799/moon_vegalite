// Execution of the `transform` array of a specification.

///|
fn json_literal(v : @value.Value) -> String {
  match v {
    Str(s) => s.escape()
    Num(x) => @util.js_number_to_string(x)
    Bool(true) => "true"
    Bool(false) => "false"
    Null | Undef => "null"
    Arr(a) => "[" + a.map(json_literal).join(",") + "]"
    Obj(_) => "null"
  }
}

///|
fn datum_ref(field : String) -> String {
  "datum[" + field.escape() + "]"
}

///|
/// The vega expression equivalent to a field predicate.
fn predicate_expr(p : @spec.Predicate) -> String {
  match p {
    Equal(f, v, _) => datum_ref(f) + "===" + json_literal(v)
    Lt(f, v, _) => datum_ref(f) + "<" + json_literal(v)
    Lte(f, v, _) => datum_ref(f) + "<=" + json_literal(v)
    Gt(f, v, _) => datum_ref(f) + ">" + json_literal(v)
    Gte(f, v, _) => datum_ref(f) + ">=" + json_literal(v)
    Range(f, a, b, _) =>
      "inrange(" +
      datum_ref(f) +
      ", [" +
      json_literal(a) +
      ", " +
      json_literal(b) +
      "])"
    OneOf(f, vs, _) =>
      "indexof([" +
      vs.map(json_literal).join(",") +
      "], " +
      datum_ref(f) +
      ") !== -1"
    Valid(f) =>
      "isValid(" + datum_ref(f) + ") && isFinite(+" + datum_ref(f) + ")"
    And(ps) => ps.map(fn(q) { "(" + predicate_expr(q) + ")" }).join(" && ")
    Or(ps) => ps.map(fn(q) { "(" + predicate_expr(q) + ")" }).join(" || ")
    Not(q) => "!(" + predicate_expr(q) + ")"
    Expr(src) => src
  }
}

///|
fn num_prop(m : Map[String, @value.Value], key : String) -> Double? {
  match m.get(key) {
    Some(Num(x)) => Some(x)
    _ => None
  }
}

///|
fn bin_params(
  rows : Array[Map[String, @value.Value]],
  field : String,
  m : Map[String, @value.Value],
  default_maxbins : Double,
) -> @transform.BinParams {
  let extent = match m.get("extent") {
    Some(Arr([Num(a), Num(b)])) => (a, b)
    _ =>
      match @transform.extent(rows, field) {
        Some(e) => e
        None => (0.0, 0.0)
      }
  }
  let maxbins = match num_prop(m, "maxbins") {
    Some(v) => v
    None => default_maxbins
  }
  let nice = match m.get("nice") {
    Some(Bool(false)) => false
    _ => true
  }
  @transform.BinParams::new(
    extent,
    maxbins~,
    base=match num_prop(m, "base") {
      Some(v) => v
      None => 10.0
    },
    step?=num_prop(m, "step"),
    minstep=match num_prop(m, "minstep") {
      Some(v) => v
      None => 0.0
    },
    nice~,
    anchor?=num_prop(m, "anchor"),
  )
}

///|
fn transform_err(e : @transform.TransformError) -> CompileError {
  match e {
    TransformError(m) => CompileError(m)
  }
}

///|
fn apply_transforms(
  rows0 : Array[Map[String, @value.Value]],
  ts : Array[@spec.Transform],
) -> Array[Map[String, @value.Value]] raise CompileError {
  let mut rows = rows0
  for t in ts {
    match t {
      Filter(Expr(src)) =>
        rows = @transform.filter(rows, src) catch {
          e => raise transform_err(e)
        }
      Filter(Predicate(p)) =>
        rows = @transform.filter(rows, predicate_expr(p)) catch {
          e => raise transform_err(e)
        }
      Calculate(src, as_name) =>
        @transform.formula(rows, src, as_name) catch {
          e => raise transform_err(e)
        }
      Aggregate(ops, groupby) =>
        rows = @transform.aggregate(
          rows,
          groupby,
          ops.map(fn(o) { { op: o.op, field: o.field, out: o.out, } }),
        ) catch {
          e => raise transform_err(e)
        }
      Bin(field, props, as_names) => {
        let p = bin_params(rows, field, props, 10.0)
        let a0 = as_names[0]
        let a1 = if as_names.length() > 1 { as_names[1] } else { a0 + "_end" }
        @transform.bin_rows(rows, field, p, a0, a1)
      }
      TimeUnit(unit, field, as_name) =>
        @transform.timeunit(
          rows,
          field,
          [unit],
          as0=as_name,
          as1=as_name + "_end",
        ) catch {
          e => raise transform_err(e)
        }
      Fold(fields, as_names) =>
        rows = @transform.fold(rows, fields, as_names[0], as_names[1])
    }
  }
  rows
}
