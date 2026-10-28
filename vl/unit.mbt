// Compilation of a single-view specification with x / y position channels.

///|
/// A position channel with everything resolved from its definition.
priv struct Pos {
  def : @spec.ChannelDef
  typ : String
  /// the data field this channel reads after the data pipeline
  field : String
  title : String
  discrete : Bool
  temporal : Bool
  time_unit : String?
  aggregate : String?
}

///|
fn derived_field(def : @spec.ChannelDef) -> String raise CompileError {
  match (def.aggregate, def.field) {
    (Some("count"), _) => "__count"
    (Some(op), Some(f)) => op + "_" + f
    (None, Some(f)) =>
      match def.bin {
        Some(m) => bin_name(m) + "_" + f
        None =>
          match def.time_unit {
            Some(u) => u + "_" + f
            None => f
          }
      }
    _ => raise CompileError("channel 缺少 field")
  }
}

///|
/// vega-lite's `binToString` for the supported parameters.
fn bin_name(m : Map[String, @value.Value]) -> String {
  match (m.get("maxbins"), m.get("step")) {
    (Some(Num(n)), _) =>
      "bin_maxbins_" + underscore(@util.js_number_to_string(n))
    (_, Some(Num(n))) => "bin_step_" + underscore(@util.js_number_to_string(n))
    _ => "bin_maxbins_10"
  }
}

///|
fn underscore(s : String) -> String {
  s.replace_all(old=".", new="_").replace_all(old="-", new="_")
}

///|
/// `titleCase`: upper-case the first character.
fn capitalize(s : String) -> String {
  if s.length() == 0 {
    s
  } else {
    s[0:1].to_upper().to_owned() + s[1:].to_owned()
  }
}

///|
fn default_title(def : @spec.ChannelDef) -> String raise CompileError {
  match (def.aggregate, def.field) {
    (Some("count"), _) => "Count of Records"
    (Some(op), Some(f)) => capitalize(op) + " of " + f
    (None, Some(f)) =>
      if def.bin is Some(_) {
        f + " (binned)"
      } else {
        match def.time_unit {
          Some(u) => f + " (" + unit_parts(u).join("-") + ")"
          None => f
        }
      }
    _ => raise CompileError("channel 缺少 field")
  }
}

///|
fn resolve_pos(
  _chan : String,
  def : @spec.ChannelDef,
) -> Pos raise CompileError {
  let typ = match def.typ {
    Some(t) => t
    None =>
      if def.aggregate is Some(_) {
        "quantitative"
      } else if def.time_unit is Some(_) {
        "temporal"
      } else if def.bin is Some(_) {
        "quantitative"
      } else {
        match def.scale {
          Some(m) =>
            match m.get("type") {
              Some(Str("log"))
              | Some(Str("linear"))
              | Some(Str("sqrt"))
              | Some(Str("pow")) => "quantitative"
              Some(Str("time")) | Some(Str("utc")) => "temporal"
              _ => "nominal"
            }
          None => "nominal"
        }
      }
  }
  let title = match def.title {
    Some(Some(t)) => t
    _ => default_title(def)
  }
  {
    def,
    typ,
    field: derived_field(def),
    title,
    discrete: typ == "nominal" || typ == "ordinal",
    temporal: typ == "temporal",
    time_unit: def.time_unit,
    aggregate: def.aggregate,
  }
}

///|
/// `{step: n}` sizes, or a plain number.
fn step_of(v : @value.Value?) -> Double? {
  match v {
    Some(Obj(m)) =>
      match m.get("step") {
        Some(Num(x)) => Some(x)
        _ => None
      }
    _ => None
  }
}

///|
fn mark_color(spec : @spec.Spec) -> String {
  match spec.mark.props.get("color") {
    Some(Str(c)) => c
    _ => "#4c78a8"
  }
}

///|
fn domain_extent_multi(
  srcs : Array[(Array[Map[String, @value.Value]], Array[String])],
  zero : Bool,
) -> (Double, Double)? {
  let mut lo = @double.infinity
  let mut hi = @double.neg_infinity
  let mut nfields = 0
  for src in srcs {
    let (rows, fields) = src
    nfields += fields.length()
    for f in fields {
      match @transform.extent(rows, f) {
        Some((a, b)) => {
          lo = min(lo, a)
          hi = max(hi, b)
        }
        None => ()
      }
    }
  }
  if lo > hi {
    // no data: one field leaves the domain undefined (NaN); several fields
    // give an inverted infinite extent that `zero` collapses to [0, 0]
    return if nfields > 1 {
      if zero {
        Some((0.0, 0.0))
      } else {
        Some((@double.infinity, @double.neg_infinity))
      }
    } else {
      Some((@double.not_a_number, @double.not_a_number))
    }
  }
  if zero {
    lo = min(lo, 0.0)
    hi = max(hi, 0.0)
  }
  Some((lo, hi))
}

///|
fn domain_extent(
  rows : Array[Map[String, @value.Value]],
  fields : Array[String],
  zero : Bool,
) -> (Double, Double)? {
  domain_extent_multi([(rows, fields)], zero)
}

///|
/// Distinct values of several fields of several sources, in ascending order.
fn sorted_unique_multi(
  srcs : Array[(Array[Map[String, @value.Value]], Array[String])],
) -> Array[@value.Value] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[@value.Value] = []
  for src in srcs {
    let (rows, fields) = src
    for f in fields {
      for v in first_appearance(rows, f) {
        let k = @scale.value_key(v)
        if !seen.contains(k) {
          seen[k] = true
          out.push(v)
        }
      }
    }
  }
  @transform.stable_sort(out, fn(a, b) { @value.compare_values(a, b) })
}

///|
/// The scale of a position channel; `size` is the view size along it (None
/// for a discrete scale whose size follows from its step).
fn pos_scale(
  p : Pos,
  srcs : Array[(Array[Map[String, @value.Value]], Array[String])],
  mark : String,
  range_start : Double,
  range_stop : Double,
  bins : (Double, Double, Double)?,
  zero_default : Bool,
  order : Array[@value.Value]?,
) -> (RScale, Array[@value.Value]) {
  if p.def.bin is Some(_) && bins is Some((start, stop, step)) {
    let c = @scale.Continuous::new(Linear)
    c.domain = [start, stop]
    c.range = [range_start, range_stop]
    let seq : Array[Double] = []
    let n = ((stop + step / 2.0 - start) / step).ceil()
    let mut i = 0.0
    while i < n {
      seq.push(start + i * step)
      i += 1.0
    }
    (Binned(c, seq), [])
  } else if p.discrete {
    let domain = match order {
      Some(o) => o
      None => sorted_unique_multi(srcs)
    }
    let band = if mark == "bar" ||
      mark == "rect" ||
      mark == "tick" ||
      mark == "rule" {
      let b = @scale.Band::band()
      let inner = if mark == "bar" {
        0.1
      } else if mark == "tick" {
        0.25
      } else {
        0.0
      }
      b.set_padding_inner(inner)
      b.set_padding_outer(inner / 2.0)
      b
    } else {
      let b = @scale.Band::point()
      b.set_padding(0.5)
      b
    }
    band.set_domain(domain)
    band.set_range(range_start, range_stop)
    (Band(band), domain)
  } else if p.temporal {
    let c = @scale.Continuous::new(Linear)
    match domain_extent_multi(srcs, false) {
      Some((lo, hi)) => c.domain = [lo, hi]
      None => ()
    }
    c.range = [range_start, range_stop]
    (Time(c), [])
  } else {
    let sprops : Map[String, @value.Value] = match p.def.scale {
      Some(m) => m
      None => Map([])
    }
    let stype = match sprops.get("type") {
      Some(Str(t)) => t
      _ => "linear"
    }
    let kind = match stype {
      "log" =>
        @scale.ScaleKind::Log(
          match sprops.get("base") {
            Some(Num(b)) => b
            _ => 10.0
          },
        )
      "sqrt" => @scale.ScaleKind::sqrt()
      "pow" =>
        @scale.ScaleKind::Pow(
          match sprops.get("exponent") {
            Some(Num(e)) => e
            _ => 1.0
          },
        )
      _ => @scale.ScaleKind::Linear
    }
    let c = @scale.Continuous::new(kind)
    let user_domain = match sprops.get("domain") {
      Some(Arr(a)) if a.length() >= 2 => Some(a.map(fn(v) { v.to_number() }))
      _ => None
    }
    let zero = match sprops.get("zero") {
      Some(Bool(z)) => z
      _ =>
        if user_domain is Some(_) || kind is Log(_) {
          false
        } else {
          zero_default
        }
    }
    match user_domain {
      Some(d) => c.domain = d
      None =>
        match domain_extent_multi(srcs, zero) {
          Some((lo, hi)) => c.domain = [lo, hi]
          None => ()
        }
    }
    match sprops.get("domainMin") {
      Some(Num(v)) => c.domain[0] = v
      _ => ()
    }
    match sprops.get("domainMax") {
      Some(Num(v)) => c.domain[c.domain.length() - 1] = v
      _ => ()
    }
    c.range = [range_start, range_stop]
    match sprops.get("range") {
      Some(Arr([Num(a), Num(b)])) => c.range = [a, b]
      _ => ()
    }
    match sprops.get("reverse") {
      Some(Bool(true)) => c.range = [c.range[1], c.range[0]]
      _ => ()
    }
    match sprops.get("clamp") {
      Some(Bool(true)) => c.clamp = true
      _ => ()
    }
    let nice = match sprops.get("nice") {
      Some(Bool(n)) => n
      Some(Num(_)) => true
      _ =>
        user_domain is None &&
        sprops.get("domainMin") is None &&
        sprops.get("domainMax") is None
    }
    if nice {
      c.nice()
    }
    (Cont(c), [])
  }
}

///|
priv struct UnitModel {
  spec : @spec.Spec
  mark : String
  px : Pos?
  py : Pos?
  px2 : Pos?
  py2 : Pos?
  pcolor : Pos?
  psize : Pos?
  popacity : Pos?
  pshape : Pos?
  ptext : Pos?
  color_value : String?
  size_value : Double?
  opacity_value : Double?
  shape_value : String?
  bin_info : Map[String, (Double, Double, Double)]
  orient : String
  vertical : Bool
  config_zero : Bool
  stack_chan : String?
  stack_offset : String
  valid_fields : Array[String]
  data : Array[Map[String, @value.Value]]
  xfields : Array[String]
  yfields : Array[String]
  x_order : Array[@value.Value]?
  y_order : Array[@value.Value]?
}

///|
priv struct UnitScales {
  xs : (RScale, Array[@value.Value])?
  ys : (RScale, Array[@value.Value])?
  base_color : String
  color_scale : @scale.Ordinal
  color_domain : Array[@value.Value]
  color_seq : @scale.Sequential?
  size_scale : @scale.Continuous?
  opacity_scale : @scale.Continuous?
  shape_scale : @scale.Ordinal
  shape_domain : Array[@value.Value]
}

///|
/// Run the data pipeline of a unit specification and resolve its channels.
fn build_unit(spec : @spec.Spec) -> UnitModel raise CompileError {
  let source = match spec.data {
    Some(d) => d
    None => raise CompileError("data 缺失")
  }
  let mark = spec.mark.typ
  if mark != "bar" &&
    mark != "point" &&
    mark != "tick" &&
    mark != "line" &&
    mark != "area" &&
    mark != "rule" &&
    mark != "text" &&
    mark != "rect" &&
    mark != "circle" &&
    mark != "square" {
    raise CompileError("mark " + mark + " 暂不支持")
  }
  let mut rows = source.map(fn(r) { r.copy() })
  // temporal fields are parsed to dates (vega `toDate`)
  for d in [find_channel(spec, "x"), find_channel(spec, "y")] {
    match d {
      Some({ field: Some(f), aggregate: None, typ, time_unit, .. }) =>
        if typ == Some("temporal") || time_unit is Some(_) {
          for r in rows {
            r[f] = @value.get_field(r, f).coerce_date()
          }
        }
      _ => ()
    }
  }
  // user transforms
  rows = apply_transforms(rows, spec.transform)
  for d in [find_channel(spec, "x"), find_channel(spec, "y")] {
    match d {
      Some({ field: Some(f), time_unit: Some(u), .. }) =>
        @transform.timeunit(
          rows,
          f,
          unit_parts(u),
          as0=u + "_" + f,
          as1=u + "_" + f + "_end",
        ) catch {
          @time.TimeError(m) => raise CompileError(m)
          @transform.TransformError(m) => raise CompileError(m)
          _ => raise CompileError("timeUnit 失败")
        }
      _ => ()
    }
  }
  // binned fields
  let bin_info : Map[String, (Double, Double, Double)] = Map([])
  for ch in ["x", "y"] {
    match find_channel(spec, ch) {
      Some({ field: Some(f), bin: Some(m), aggregate: None, .. } as d) => {
        let name = derived_field(d)
        let p = bin_params(rows, f, m, 10.0)
        let bins = @transform.compute_bins(p)
        bin_info[ch] = (bins.start, bins.stop, bins.step)
        @transform.bin_rows(rows, f, p, name, name + "_end")
      }
      _ => ()
    }
  }
  let xdef = find_channel(spec, "x")
  let ydef = find_channel(spec, "y")
  let px = match xdef {
    Some(d) => Some(resolve_pos("x", d))
    None => None
  }
  let py = match ydef {
    Some(d) => Some(resolve_pos("y", d))
    None => None
  }
  let positions : Array[Pos] = []
  match px {
    Some(p) => positions.push(p)
    None => ()
  }
  match py {
    Some(p) => positions.push(p)
    None => ()
  }
  let pcolor : Pos? = match find_channel(spec, "color") {
    Some({ field: Some(_), .. } as d) => Some(resolve_pos("color", d))
    _ => None
  }
  let px2 : Pos? = match find_channel(spec, "x2") {
    Some({ field: Some(_), .. } as d) => Some(resolve_pos("x2", d))
    _ => None
  }
  let py2 : Pos? = match find_channel(spec, "y2") {
    Some({ field: Some(_), .. } as d) => Some(resolve_pos("y2", d))
    _ => None
  }
  let px = match (px, px2) {
    (Some(a), Some(b)) => Some({ ..a, title: merge_titles(a.title, b.title), })
    _ => px
  }
  let py = match (py, py2) {
    (Some(a), Some(b)) => Some({ ..a, title: merge_titles(a.title, b.title), })
    _ => py
  }
  let psize : Pos? = match find_channel(spec, "size") {
    Some({ field: Some(_), .. } as d) => Some(resolve_pos("size", d))
    _ => None
  }
  let popacity : Pos? = match find_channel(spec, "opacity") {
    Some({ field: Some(_), .. } as d) => Some(resolve_pos("opacity", d))
    _ => None
  }
  let pshape : Pos? = match find_channel(spec, "shape") {
    Some({ field: Some(_), .. } as d) => Some(resolve_pos("shape", d))
    _ => None
  }
  let size_value : Double? = match find_channel(spec, "size") {
    Some({ value: Some(Num(v)), .. }) => Some(v)
    _ => None
  }
  let opacity_value : Double? = match find_channel(spec, "opacity") {
    Some({ value: Some(Num(v)), .. }) => Some(v)
    _ => None
  }
  let shape_value : String? = match find_channel(spec, "shape") {
    Some({ value: Some(Str(v)), .. }) => Some(v)
    _ => None
  }
  if mark != "point" && mark != "circle" && mark != "square" {
    for ch in ["size", "opacity", "shape"] {
      if find_channel(spec, ch) is Some(_) &&
        !(ch == "opacity" && (mark == "bar" || mark == "tick" || mark == "area")) {
        raise CompileError(
          "encoding." + ch + " 暂不支持用于 mark " + mark,
        )
      }
    }
  }
  let ptext : Pos? = match find_channel(spec, "text") {
    Some({ field: Some(_), .. } as d) => Some(resolve_pos("text", d))
    _ => None
  }
  let color_value : String? = match find_channel(spec, "color") {
    Some({ value: Some(Str(c)), .. }) => Some(c)
    _ => None
  }
  // encoding-level aggregates
  let measures : Array[@transform.Measure] = []
  let groupby : Array[String] = []
  let measured : Array[Pos] = positions.copy()
  for o in [px2, py2, ptext, psize, popacity, pshape] {
    match o {
      Some(p) => measured.push(p)
      None => ()
    }
  }
  for p in measured {
    match p.aggregate {
      Some(op) =>
        measures.push({
          op,
          field: if op == "count" {
            None
          } else {
            p.def.field
          },
          out: p.field,
        })
      None => {
        groupby.push(p.field)
        if is_ranged(mark, p) {
          groupby.push(p.field + "_end")
        }
      }
    }
  }
  match pcolor {
    Some(c) => groupby.push(c.field)
    None => ()
  }
  for o in [psize, popacity, pshape] {
    match o {
      Some(p) => if p.aggregate is None { groupby.push(p.field) }
      None => ()
    }
  }
  let has_aggregate = measures.length() > 0
  let rows_pre = rows
  if has_aggregate {
    rows = @transform.aggregate(rows, groupby, measures) catch {
      @transform.TransformError(m) => raise CompileError(m)
    }
  }
  // orientation of bars: continuous field along the other axis
  let x_cont = match px {
    Some(p) => !p.discrete
    None => false
  }
  let y_cont = match py {
    Some(p) => !p.discrete
    None => false
  }
  let orient = infer_orient(mark, px, py)
  let config_zero = match spec.config.get("scale") {
    Some(Obj(m)) =>
      match m.get("zero") {
        Some(Bool(z)) => z
        _ => true
      }
    _ => true
  }
  let vertical = orient != "horizontal"
  ignore(x_cont)
  ignore(y_cont)
  // stacking: bars with an unaggregated continuous field
  let stack_chan0 : String? = if (mark == "bar" || mark == "area") &&
    !(has_aggregate && pcolor is None) {
    match (px, py) {
      (Some(x), Some(y)) =>
        if x.typ == "quantitative" && y.typ != "quantitative" {
          Some("x")
        } else if y.typ == "quantitative" && x.typ != "quantitative" {
          Some("y")
        } else {
          None
        }
      _ => None
    }
  } else {
    None
  }
  let stack_req : String? = match stack_chan0 {
    Some("y") => py.unwrap().def.stack
    Some("x") => px.unwrap().def.stack
    _ => None
  }
  let stack_chan = if stack_req == Some("none") { None } else { stack_chan0 }
  let stack_offset = match stack_req {
    Some(o) => o
    None => "zero"
  }
  let stacked_field = match stack_chan {
    Some("y") => py.unwrap().field
    Some("x") => px.unwrap().field
    _ => ""
  }
  match stack_chan {
    Some(c) => {
      let dim = if c == "y" { px.unwrap().field } else { py.unwrap().field }
      @transform.stack(
        rows,
        Some(stacked_field),
        [dim],
        match pcolor {
          Some(c) => Some({ fields: [c.field], descending: [true], })
          None => None
        },
        stack_offset,
        stacked_field + "_start",
        stacked_field + "_end",
      )
    }
    None => ()
  }
  // drop invalid values of continuous position fields
  let valid_fields : Array[String] = []
  for p in positions {
    if !p.discrete && p.aggregate != Some("count") {
      valid_fields.push(p.field)
    }
  }
  for o in [psize, popacity, pcolor] {
    match o {
      Some(p) =>
        if p.typ == "quantitative" && p.aggregate != Some("count") {
          valid_fields.push(p.field)
        }
      None => ()
    }
  }
  let is_path = mark == "line" || mark == "area"
  let data = if is_path {
    rows
  } else {
    rows.filter(fn(r) {
      valid_fields.all(fn(f) { is_finite_valid(@value.get_field(r, f)) })
    })
  }
  // domain fields and sort orders of the position scales
  let xfields = match px {
    Some(p) =>
      if stack_chan == Some("x") {
        [p.field + "_start", p.field + "_end"]
      } else if is_ranged(mark, p) {
        [p.field, p.field + "_end"]
      } else {
        match px2 {
          Some(q) => [p.field, q.field]
          None => [p.field]
        }
      }
    None => []
  }
  let yfields = match py {
    Some(p) =>
      if stack_chan == Some("y") {
        [p.field + "_start", p.field + "_end"]
      } else if is_ranged(mark, p) {
        [p.field, p.field + "_end"]
      } else {
        match py2 {
          Some(q) => [p.field, q.field]
          None => [p.field]
        }
      }
    None => []
  }
  let x_order = match px {
    Some({ def: { sort: Some(sv), .. }, discrete: true, .. } as p) =>
      sort_domain(p, sv, rows_pre, data, px, py)
    _ => None
  }
  let y_order = match py {
    Some({ def: { sort: Some(sv), .. }, discrete: true, .. } as p) =>
      sort_domain(p, sv, rows_pre, data, px, py)
    _ => None
  }
  {
    spec,
    mark,
    px,
    py,
    px2,
    py2,
    pcolor,
    psize,
    popacity,
    pshape,
    ptext,
    color_value,
    size_value,
    opacity_value,
    shape_value,
    bin_info,
    orient,
    vertical,
    config_zero,
    stack_chan,
    stack_offset,
    valid_fields,
    data,
    xfields,
    yfields,
    x_order,
    y_order,
  }
}

///|
/// The size of the plot area.
fn unit_size(u : UnitModel) -> (Double, Double) {
  let spec = u.spec
  let data = u.data
  let count = fn(p : Pos?) -> Int32 {
    match p {
      Some(q) if q.discrete => sorted_unique(data, q.field).length()
      _ => 0
    }
  }
  (
    axis_size(u.px, count(u.px), u.mark, step_of(spec.width), 200.0, spec.width),
    axis_size(
      u.py,
      count(u.py),
      u.mark,
      step_of(spec.height),
      200.0,
      spec.height,
    ),
  )
}

///|
/// The size of the plot area along one axis: `step * bandspace` for a discrete
/// scale with `n_discrete` domain values, the given size or 200 for a
/// continuous one, and 20 when the channel is missing.
fn axis_size(
  p : Pos?,
  n_discrete : Int32,
  mark : String,
  step : Double?,
  dflt : Double,
  spec_size : @value.Value?,
) -> Double {
  match p {
    Some(q) if q.discrete => {
      let n = n_discrete.to_double()
      let (pi, po) = if mark == "bar" {
        (0.1, 0.05)
      } else if mark == "tick" {
        (0.25, 0.125)
      } else if mark == "rect" || mark == "rule" {
        (0.0, 0.0)
      } else {
        (1.0, 0.5)
      }
      let s = match step {
        Some(v) => v
        None => 20.0
      }
      if mark == "bar" || mark == "tick" || mark == "rect" || mark == "rule" {
        @scale.band_space(n, pi, po) * s
      } else {
        @scale.band_space(n, 1.0, 0.5) * s
      }
    }
    Some(_) =>
      match spec_size {
        Some(Num(v)) => v
        _ => dflt
      }
    None =>
      match spec_size {
        Some(Num(v)) => v
        _ => 20.0
      }
  }
}

///|
/// Position scales and the scales of the non-positional channels.
fn unit_scales(
  u : UnitModel,
  width : Double,
  height : Double,
  xs_shared? : (RScale, Array[@value.Value]),
  ys_shared? : (RScale, Array[@value.Value]),
) -> UnitScales {
  let spec = u.spec
  let mark = u.mark
  let px = u.px
  let py = u.py
  let px2 = u.px2
  let py2 = u.py2
  let pcolor = u.pcolor
  let psize = u.psize
  let popacity = u.popacity
  let pshape = u.pshape
  let color_value = u.color_value
  let bin_info = u.bin_info
  let orient = u.orient
  let config_zero = u.config_zero
  let data = u.data
  let xfields = u.xfields
  let yfields = u.yfields
  let x_order = u.x_order
  let y_order = u.y_order
  let xs = match xs_shared {
    Some(_) => xs_shared
    None =>
      match px {
        Some(p) =>
          Some(
            pos_scale(
              p,
              [(data, xfields)],
              mark,
              0.0,
              width,
              bin_info.get("x"),
              zero_of_chan(mark, orient, "x", px2 is Some(_), config_zero),
              x_order,
            ),
          )
        None => None
      }
  }
  let ys = match ys_shared {
    Some(_) => ys_shared
    None =>
      match py {
        Some(p) =>
          Some(
            pos_scale(
              p,
              [(data, yfields)],
              mark,
              if p.discrete {
                0.0
              } else {
                height
              },
              if p.discrete {
                height
              } else {
                0.0
              },
              bin_info.get("y"),
              zero_of_chan(mark, orient, "y", py2 is Some(_), config_zero),
              y_order,
            ),
          )
        None => None
      }
  }
  let base_color = match color_value {
    Some(c) => c
    None => mark_color(spec)
  }
  let color_scale = @scale.Ordinal::new()
  let color_is_quant = match pcolor {
    Some(c) => c.typ == "quantitative"
    None => false
  }
  let color_domain = match pcolor {
    Some(c) if !color_is_quant => sorted_unique(data, c.field)
    _ => []
  }
  let color_seq : @scale.Sequential? = match pcolor {
    Some(c) if color_is_quant =>
      match @scale.scheme_interpolator("blues") {
        Some(f) => {
          let sq = @scale.Sequential::new(Linear, f)
          match domain_extent(data, [c.field], false) {
            Some((lo, hi)) => sq.scale.domain = [lo, hi]
            None => ()
          }
          Some(sq)
        }
        _ => None
      }
    _ => None
  }
  color_scale.set_domain(color_domain)
  match @scale.scheme("tableau10") {
    Some(Discrete(cs)) => color_scale.set_range(cs.map(fn(c) { Str(c) }))
    _ => ()
  }
  let step_w = match step_of(spec.width) {
    Some(v) => v
    None => 20.0
  }
  let step_h = match step_of(spec.height) {
    Some(v) => v
    None => 20.0
  }
  let max_size = {
    let m = 0.95 * min(step_w, step_h)
    m * m
  }
  let size_scale = match psize {
    Some(p) => Some(extent_scale(data, p.field, true, 4.0, max_size))
    None => None
  }
  let opacity_scale = match popacity {
    Some(p) => Some(extent_scale(data, p.field, false, 0.3, 0.8))
    None => None
  }
  let shape_scale = @scale.Ordinal::new()
  let shape_domain = match pshape {
    Some(p) => sorted_unique(data, p.field)
    None => []
  }
  shape_scale.set_domain(shape_domain)
  shape_scale.set_range(symbol_shapes.map(fn(x) { Str(x) }))
  {
    xs,
    ys,
    base_color,
    color_scale,
    color_domain,
    color_seq,
    size_scale,
    opacity_scale,
    shape_scale,
    shape_domain,
  }
}

///|
fn unit_axes(
  u : UnitModel,
  sc : UnitScales,
  width : Double,
  height : Double,
  x_orient~ : String = "bottom",
  y_orient~ : String = "left",
  with_x~ : Bool = true,
  with_y~ : Bool = true,
  with_grid~ : Bool = true,
) -> Array[Axis] raise CompileError {
  let px = u.px
  let py = u.py
  let stack_chan = u.stack_chan
  let stack_offset = u.stack_offset
  let xs = sc.xs
  let ys = sc.ys
  // axes
  let axes : Array[Axis] = []
  let tick_x = tick_count_of(px, width)
  let tick_y = tick_count_of(py, height)
  let grid_props = fn(
    axis : @spec.Guide,
    p : Pos?,
  ) -> Map[String, @value.Value] raise CompileError {
    let m : Map[String, @value.Value] = Map([
      ("grid", Bool(true)),
      ("domain", Bool(false)),
      ("labels", Bool(false)),
      ("aria", Bool(false)),
      ("maxExtent", Num(0.0)),
      ("minExtent", Num(0.0)),
      ("ticks", Bool(false)),
    ])
    match axis {
      Props(a) =>
        for k, v in a {
          if k.has_prefix("grid") && k != "grid" {
            m[k] = v
          }
        }
      _ => ()
    }
    match p {
      Some(q) =>
        match q.time_unit {
          Some(u) =>
            match unit_duration(unit_parts(u)) {
              Some(d) => m["tickMinStep"] = Num(d)
              None => ()
            }
          None => ()
        }
      None => ()
    }
    m
  }
  match (px, xs, ys) {
    (Some(p), Some((s, _)), _) =>
      if !p.discrete && p.def.bin is None {
        match ys {
          Some((gs, _)) =>
            axes.push(
              build_axis(
                {
                  scale: s,
                  domain: [],
                  orient: x_orient,
                  title: None,
                  props: grid_props(p.def.axis, Some(p)),
                  grid_scale: Some(gs),
                  tick_count: tick_x,
                },
                width,
                height,
              ),
            )
          None =>
            axes.push(
              build_axis(
                {
                  scale: s,
                  domain: [],
                  orient: x_orient,
                  title: None,
                  props: grid_props(p.def.axis, Some(p)),
                  grid_scale: None,
                  tick_count: tick_x,
                },
                width,
                height,
              ),
            )
        }
      }
    _ => ()
  }
  match (py, ys, xs) {
    (Some(p), Some((s, _)), _) =>
      if !p.discrete && p.def.bin is None {
        axes.push(
          build_axis(
            {
              scale: s,
              domain: [],
              orient: y_orient,
              title: None,
              props: grid_props(p.def.axis, Some(p)),
              grid_scale: match xs {
                Some((gs, _)) => Some(gs)
                None => None
              },
              tick_count: tick_y,
            },
            width,
            height,
          ),
        )
      }
    _ => ()
  }
  match (px, xs) {
    (Some(p), Some((s, d))) => {
      let props : Map[String, @value.Value] = Map([])
      if p.discrete {
        let user_angle = match p.def.axis {
          Props(m) =>
            match m.get("labelAngle") {
              Some(Num(a)) => Some(a)
              _ => None
            }
          _ => None
        }
        let angle = match user_angle {
          Some(a) => Some(a)
          None => if p.time_unit is None { Some(270.0) } else { None }
        }
        label_angle_props("x", angle, x_orient, props)
        if p.time_unit is Some(_) {
          props["labelOverlap"] = Bool(true)
        }
      } else {
        props["labelFlush"] = Bool(true)
        props["labelOverlap"] = Bool(true)
      }
      if stack_chan == Some("x") && stack_offset == "normalize" {
        props["format"] = Str(".0%")
      }
      time_axis_props(p, props)
      apply_axis_spec(props, p.def.axis)
      axes.push(
        build_axis(
          {
            scale: s,
            domain: d,
            orient: x_orient,
            title: if p.def.title is Some(None) {
              None
            } else {
              Some(p.title)
            },
            props,
            grid_scale: None,
            tick_count: tick_x,
          },
          width,
          height,
        ),
      )
    }
    _ => ()
  }
  match (py, ys) {
    (Some(p), Some((s, d))) => {
      let props : Map[String, @value.Value] = Map([])
      if !p.discrete || p.time_unit is Some(_) {
        props["labelOverlap"] = if is_log(p) {
          Str("greedy")
        } else {
          Bool(true)
        }
      }
      match p.def.axis {
        Props(m) =>
          match m.get("labelAngle") {
            Some(Num(a)) => label_angle_props("y", Some(a), y_orient, props)
            _ => ()
          }
        _ => ()
      }
      if stack_chan == Some("y") && stack_offset == "normalize" {
        props["format"] = Str(".0%")
      }
      time_axis_props(p, props)
      apply_axis_spec(props, p.def.axis)
      axes.push(
        build_axis(
          {
            scale: s,
            domain: d,
            orient: y_orient,
            title: if p.def.title is Some(None) {
              None
            } else {
              Some(p.title)
            },
            props,
            grid_scale: None,
            tick_count: tick_y,
          },
          width,
          height,
        ),
      )
    }
    _ => ()
  }
  let hidden : Array[String] = []
  match px {
    Some({ def: { axis: Off, .. }, .. }) => hidden.push(x_orient)
    _ => ()
  }
  match py {
    Some({ def: { axis: Off, .. }, .. }) => hidden.push(y_orient)
    _ => ()
  }
  axes.filter(fn(a) {
    !hidden.contains(a.orient) &&
    (with_x || a.orient != x_orient) &&
    (with_y || a.orient != y_orient) &&
    (with_grid || !a.has_grid)
  })
}

///|
fn unit_mark(
  u : UnitModel,
  sc : UnitScales,
  width : Double,
  height : Double,
  name~ : String = "marks",
) -> @scene.Mark raise CompileError {
  let spec = u.spec
  let mark = u.mark
  let px = u.px
  let py = u.py
  let px2 = u.px2
  let py2 = u.py2
  let pcolor = u.pcolor
  let psize = u.psize
  let popacity = u.popacity
  let pshape = u.pshape
  let ptext = u.ptext
  let color_value = u.color_value
  let size_value = u.size_value
  let opacity_value = u.opacity_value
  let shape_value = u.shape_value
  let orient = u.orient
  let vertical = u.vertical
  let stack_chan = u.stack_chan
  let valid_fields = u.valid_fields
  let data = u.data
  let xs = sc.xs
  let ys = sc.ys
  let base_color = sc.base_color
  let color_scale = sc.color_scale
  let color_seq = sc.color_seq
  let size_scale = sc.size_scale
  let opacity_scale = sc.opacity_scale
  let shape_scale = sc.shape_scale
  let default_opacity = has_default_opacity(mark, spec)
  let color_of = fn(r : Map[String, @value.Value]) -> String {
    match pcolor {
      Some(c) if color_seq is Some(_) =>
        match color_seq.unwrap().map(@value.get_field(r, c.field).to_number()) {
          Some(v) => v
          None => base_color
        }
      Some(c) =>
        match color_scale.map(@value.get_field(r, c.field)) {
          Some(Str(v)) => v
          _ => base_color
        }
      None => base_color
    }
  }
  let items : Array[@scene.Item] = []
  let pos_of = fn(
    s : (RScale, Array[@value.Value])?,
    r : Map[String, @value.Value],
    field : String,
  ) -> Double {
    match s {
      Some((sc, _)) =>
        match sc.map(@value.get_field(r, field)) {
          Some(v) => v
          None => @double.not_a_number
        }
      None => 0.0
    }
  }
  let zero_of = fn(s : (RScale, Array[@value.Value])?) -> Double {
    match s {
      Some((sc, _)) =>
        match sc.map(Num(0.0)) {
          Some(v) => v
          None => 0.0
        }
      None => 0.0
    }
  }
  for r in data {
    match mark {
      "bar" => {
        let it = mk_item([("fill", str(color_of(r)))])
        let px_ = px.unwrap()
        let py_ = py.unwrap()
        if vertical {
          if is_ranged(mark, px_) {
            let sv = pos_of(xs, r, px_.field)
            let ev = pos_of(xs, r, px_.field + "_end")
            let d = (ev - sv).abs()
            let x2v = sv +
              (0.5 + (if d < 0.25 { -0.5 * (0.25 - d) } else { 0.5 }))
            let xv = ev +
              (0.5 + (if d < 0.25 { 0.5 * (0.25 - d) } else { -0.5 }))
            it.set_num("x2", x2v)
            it.set_num("x", xv)
            if xv > x2v {
              it.set_num("x", x2v)
              it.set_num("x2", xv)
            }
            it.set_num("width", it.num0("x2") - it.num0("x"))
          } else {
            it.set_num("x", pos_of(xs, r, px_.field))
            it.set_num("width", max(0.25, xs.unwrap().0.bandwidth()))
          }
          let (a, b) = if stack_chan == Some("y") {
            (
              pos_of(ys, r, py_.field + "_end"),
              pos_of(ys, r, py_.field + "_start"),
            )
          } else {
            (pos_of(ys, r, py_.field), zero_of(ys))
          }
          it.set_num("y", min(a, b))
          it.set_num("y2", max(a, b))
          it.set_num("height", (b - a).abs())
        } else {
          it.set_num("y", pos_of(ys, r, py_.field))
          it.set_num("height", max(0.25, ys.unwrap().0.bandwidth()))
          let (a, b) = if stack_chan == Some("x") {
            (
              pos_of(xs, r, px_.field + "_start"),
              pos_of(xs, r, px_.field + "_end"),
            )
          } else {
            (pos_of(xs, r, px_.field), zero_of(xs))
          }
          it.set_num("x", min(a, b))
          it.set_num("x2", max(a, b))
          it.set_num("width", (b - a).abs())
        }
        items.push(it)
      }
      "line" => {
        let it = mk_item([
          ("strokeWidth", num(2.0)),
          ("stroke", str(color_of(r))),
        ])
        it.set_num("x", pos_of(xs, r, px.unwrap().field) + band_half(xs))
        it.set_num("y", pos_of(ys, r, py.unwrap().field) + band_half(ys))
        match spec.mark.props.get("interpolate") {
          Some(v) => it.set("interpolate", v)
          None => ()
        }
        it.set(
          "defined",
          Bool(
            valid_fields.all(fn(f) { is_finite_valid(@value.get_field(r, f)) }),
          ),
        )
        items.push(it)
      }
      "area" => {
        let it = mk_item([
          ("orient", str(orient_or_vertical(orient))),
          ("fill", str(color_of(r))),
        ])
        let px_ = px.unwrap()
        let py_ = py.unwrap()
        if vertical {
          it.set_num("x", pos_of(xs, r, px_.field) + band_half(xs))
          let (a, b) = if stack_chan == Some("y") {
            (
              pos_of(ys, r, py_.field + "_end"),
              pos_of(ys, r, py_.field + "_start"),
            )
          } else {
            (pos_of(ys, r, py_.field), zero_of(ys))
          }
          it.set_num("y", a)
          it.set_num("y2", b)
          it.set_num("height", b - a)
        } else {
          it.set_num("y", pos_of(ys, r, py_.field) + band_half(ys))
          let (a, b) = if stack_chan == Some("x") {
            (
              pos_of(xs, r, px_.field + "_end"),
              pos_of(xs, r, px_.field + "_start"),
            )
          } else {
            (pos_of(xs, r, px_.field), zero_of(xs))
          }
          it.set_num("x", a)
          it.set_num("x2", b)
          it.set_num("width", b - a)
        }
        match spec.mark.props.get("interpolate") {
          Some(v) => it.set("interpolate", v)
          None => ()
        }
        it.set(
          "defined",
          Bool(
            valid_fields.all(fn(f) { is_finite_valid(@value.get_field(r, f)) }),
          ),
        )
        items.push(it)
      }
      "rule" => {
        let it = mk_item([
          (
            "stroke",
            str(
              match color_value {
                Some(c) => c
                None => "black"
              },
            ),
          ),
        ])
        match (px, py) {
          (Some(a), Some(b)) =>
            if py2 is Some(_) {
              it.set_num(
                "x",
                pos_of(xs, r, a.field) + xs.unwrap().0.bandwidth() * 0.5,
              )
              it.set_num("y", pos_of(ys, r, b.field))
              it.set_num("y2", pos_of(ys, r, py2.unwrap().field))
            } else {
              it.set_num(
                "y",
                pos_of(ys, r, b.field) + ys.unwrap().0.bandwidth() * 0.5,
              )
              it.set_num("x", pos_of(xs, r, a.field))
              it.set_num("x2", pos_of(xs, r, px2.unwrap().field))
            }
          _ => raise CompileError("rule 需要 x 与 y 通道")
        }
        items.push(it)
      }
      "text" => {
        let it = mk_item([
          ("font", str("sans-serif")),
          ("fontSize", num(11.0)),
          (
            "fill",
            str(
              match pcolor {
                Some(_) => color_of(r)
                None =>
                  match color_value {
                    Some(c) => c
                    None => "black"
                  }
              },
            ),
          ),
          ("align", str("center")),
          ("baseline", str("middle")),
        ])
        it.set_num(
          "x",
          match px {
            Some(p) => pos_of(xs, r, p.field) + xs.unwrap().0.bandwidth() * 0.5
            None => width * 0.5
          },
        )
        it.set_num(
          "y",
          match py {
            Some(p) => pos_of(ys, r, p.field) + ys.unwrap().0.bandwidth() * 0.5
            None => height * 0.5
          },
        )
        it.set_str("text", text_of(r, ptext))
        items.push(it)
      }
      "rect" => {
        let it = mk_item([("fill", str(color_of(r)))])
        let a = px.unwrap()
        let b = py.unwrap()
        it.set_num("x", pos_of(xs, r, a.field))
        it.set_num("width", max(0.25, xs.unwrap().0.bandwidth()))
        it.set_num("y", pos_of(ys, r, b.field))
        it.set_num("height", max(0.25, ys.unwrap().0.bandwidth()))
        items.push(it)
      }
      "tick" => {
        let it = mk_item([("fill", str(color_of(r)))])
        if default_opacity {
          it.set_num("opacity", 0.7)
        }
        let thickness = 1.0
        if orient == "horizontal" {
          // size along x, thickness along y
          match xs {
            Some((sc, _)) => {
              it.set_num("x", pos_of(xs, r, px.unwrap().field))
              it.set_num("width", max(0.25, sc.bandwidth()))
            }
            None => {
              it.set_num("width", 0.75 * width)
              it.set_num("x", 0.0)
            }
          }
          let yc = pos_of(ys, r, py.unwrap().field)
          it.set_num("yc", yc)
          it.set_num("height", thickness)
          it.set_num("y", yc - thickness / 2.0)
        } else {
          match ys {
            Some((sc, _)) => {
              it.set_num("y", pos_of(ys, r, py.unwrap().field))
              it.set_num("height", max(0.25, sc.bandwidth()))
            }
            None => {
              let h = 0.75 * height
              it.set_num("yc", height * 0.5)
              it.set_num("height", h)
              it.set_num("y", height * 0.5 - h / 2.0)
            }
          }
          let xc = pos_of(xs, r, px.unwrap().field)
          it.set_num("xc", xc)
          it.set_num("width", thickness)
          it.set_num("x", xc - thickness / 2.0)
        }
        items.push(it)
      }
      _ => {
        // point, circle, square
        let filled_prop = match spec.mark.props.get("filled") {
          Some(Bool(true)) => true
          _ => false
        }
        let filled = mark != "point" || filled_prop
        let it = mk_item([
          ("size", num(30.0)),
          ("strokeWidth", num(2.0)),
          ("shape", str(if mark == "point" { "circle" } else { mark })),
        ])
        if default_opacity {
          it.set_num("opacity", 0.7)
        }
        if filled {
          it.set_str("fill", color_of(r))
        } else {
          it.set_str("fill", "transparent")
          it.set_str("stroke", color_of(r))
        }
        let bx = match xs {
          Some((sc, _)) => sc.bandwidth() * 0.5
          None => 0.0
        }
        let by = match ys {
          Some((sc, _)) => sc.bandwidth() * 0.5
          None => 0.0
        }
        let xv = match px {
          Some(p) => pos_of(xs, r, p.field) + bx
          None => width * 0.5
        }
        let yv = match py {
          Some(p) => pos_of(ys, r, p.field) + by
          None => height * 0.5
        }
        it.set_num("x", xv)
        it.set_num("y", yv)
        match (psize, size_scale) {
          (Some(p), Some(sc)) =>
            match sc.map(@value.get_field(r, p.field).to_number()) {
              Some(v) => it.set_num("size", v)
              None => ()
            }
          _ =>
            match size_value {
              Some(v) => it.set_num("size", v)
              None => ()
            }
        }
        match (popacity, opacity_scale) {
          (Some(p), Some(sc)) =>
            match sc.map(@value.get_field(r, p.field).to_number()) {
              Some(v) => it.set_num("opacity", v)
              None => ()
            }
          _ =>
            match opacity_value {
              Some(v) => it.set_num("opacity", v)
              None => ()
            }
        }
        match pshape {
          Some(p) =>
            match shape_scale.map(@value.get_field(r, p.field)) {
              Some(v) => it.set("shape", v)
              None => ()
            }
          None =>
            match shape_value {
              Some(v) => it.set_str("shape", v)
              None => ()
            }
        }
        items.push(it)
      }
    }
  }
  let mt = match mark {
    "point" | "circle" | "square" => @scene.MarkType::Symbol
    "line" => @scene.MarkType::Line
    "area" => @scene.MarkType::Area
    "rule" => @scene.MarkType::Rule
    "text" => @scene.MarkType::Text
    _ => @scene.MarkType::Rect
  }
  if mark == "line" || mark == "area" {
    // `sort: {field: "x"}`
    let sort_key = if vertical { "x" } else { "y" }
    let sorted = @transform.stable_sort(items, fn(a, b) {
      @value.compare_values(a.get(sort_key), b.get(sort_key))
    })
    items.clear()
    for it in sorted {
      items.push(it)
    }
  }
  let marks = @scene.Mark::new(mt, name~, role="mark", items~)
  marks
}

///|
fn unit_legends(
  u : UnitModel,
  sc : UnitScales,
  height : Double,
  skip_color~ : Bool = false,
) -> Array[Legend] raise CompileError {
  let spec = u.spec
  let default_opacity = has_default_opacity(u.mark, spec)
  let mark = u.mark
  let pcolor = u.pcolor
  let psize = u.psize
  let popacity = u.popacity
  let pshape = u.pshape
  let base_color = sc.base_color
  let color_scale = sc.color_scale
  let color_domain = sc.color_domain
  let color_seq = sc.color_seq
  let size_scale = sc.size_scale
  let opacity_scale = sc.opacity_scale
  let shape_scale = sc.shape_scale
  let shape_domain = sc.shape_domain
  let base_color = base_color
  let filled_mark = mark != "point" ||
    (match spec.mark.props.get("filled") {
      Some(Bool(true)) => true
      _ => false
    })
  let leg_chs : Array[LegCh] = []
  match pcolor {
    Some(c) if !(c.def.legend is Off) && color_seq is None && !skip_color =>
      leg_chs.push({
        channel: if filled_mark {
          "fill"
        } else {
          "stroke"
        },
        pos: c,
        kind: Disc(color_scale, color_domain),
      })
    _ => ()
  }
  match (psize, size_scale) {
    (Some(p), Some(sc)) =>
      leg_chs.push({ channel: "size", pos: p, kind: Cont(sc), })
    _ => ()
  }
  match (pshape, ()) {
    (Some(p), _) =>
      leg_chs.push({
        channel: "shape",
        pos: p,
        kind: Disc(shape_scale, shape_domain),
      })
    _ => ()
  }
  match (popacity, opacity_scale) {
    (Some(p), Some(sc)) =>
      leg_chs.push({ channel: "opacity", pos: p, kind: Cont(sc), })
    _ => ()
  }
  let legends = legends_of(
    leg_chs,
    mark,
    filled_mark,
    base_color,
    pcolor is Some(_),
    default_opacity,
  )
  match (pcolor, color_seq) {
    (Some(c), Some(sq)) =>
      if !(c.def.legend is Off) && !skip_color {
        legends.insert(
          0,
          build_gradient_legend(
            Some(c.title),
            sq,
            max(64.0, min(200.0, height)),
            if default_opacity {
              0.7
            } else {
              1.0
            },
            None,
          ),
        )
      }
    _ => ()
  }
  legends
}

///|
pub fn compile(text : String) -> Compiled raise CompileError {
  let spec = @spec.parse_spec_text(text) catch { e => raise spec_err(e) }
  if spec.layer.length() > 0 {
    return compile_layers(spec)
  }
  validate(spec)
  let u = build_unit(spec)
  let (width, height) = unit_size(u)
  let sc = unit_scales(u, width, height)
  let axes = unit_axes(u, sc, width, height)
  let marks = unit_mark(u, sc, width, height)
  let legends = unit_legends(u, sc, height)
  let title = match spec.title {
    Some(t) => Some(build_title(t))
    None => None
  }
  assemble(spec, axes, [marks], legends, title, width, height)
}

///|
/// Apply the user's `axis` object of a channel on top of the defaults.
fn apply_axis_spec(
  props : Map[String, @value.Value],
  axis : @spec.Guide,
) -> Unit {
  match axis {
    Props(m) =>
      for k, v in m {
        props[k] = v
      }
    _ => ()
  }
}

///|
fn is_measure(p : Pos?) -> Bool {
  match p {
    Some(q) => q.typ == "quantitative" && q.def.bin is None
    None => false
  }
}

///|
/// vega-lite's mark orientation (`compile/mark/init.ts`) for the supported marks.
fn infer_orient(mark : String, px : Pos?, py : Pos?) -> String {
  match mark {
    "point" | "circle" | "square" | "text" | "rect" => ""
    _ => {
      if mark == "bar" {
        match (px, py) {
          (Some(x), Some(y)) =>
            if y.aggregate is Some(_) && x.aggregate is None {
              return "vertical"
            } else if x.aggregate is Some(_) && y.aggregate is None {
              return "horizontal"
            }
          _ => ()
        }
      }
      let xm = is_measure(px)
      let ym = is_measure(py)
      if xm && !ym {
        if mark != "tick" {
          "horizontal"
        } else {
          "vertical"
        }
      } else if !xm && ym {
        if mark != "tick" {
          "vertical"
        } else {
          "horizontal"
        }
      } else if xm && ym {
        "vertical"
      } else {
        let xt = match px {
          Some(p) => p.temporal
          None => false
        }
        let yt = match py {
          Some(p) => p.temporal
          None => false
        }
        if xt && !yt {
          "vertical"
        } else if !xt && yt {
          "horizontal"
        } else {
          ""
        }
      }
    }
  }
}

///|
/// Axis properties implied by a time unit: its format, format type and the
/// minimum tick step.
fn time_axis_props(
  p : Pos,
  props : Map[String, @value.Value],
) -> Unit raise CompileError {
  match p.time_unit {
    Some(u) => {
      let parts = unit_parts(u)
      props["format"] = Str(time_unit_specifier(parts))
      if p.discrete {
        props["formatType"] = Str("time")
      }
      match unit_duration(parts) {
        Some(d) => props["tickMinStep"] = Num(d)
        None => ()
      }
    }
    None => ()
  }
}

///|
/// `labelAngle` and the label alignment / baseline that follow from it
/// (vega-lite `defaultLabelAlign` / `defaultLabelBaseline`).
fn label_angle_props(
  chan : String,
  angle : Double?,
  orient : String,
  props : Map[String, @value.Value],
) -> Unit {
  match angle {
    None => ()
    Some(a0) => {
      let a = (a0 % 360.0 + 360.0) % 360.0
      props["labelAngle"] = Num(a)
      if chan == "x" {
        if a % 180.0 != 0.0 {
          let left = (0.0 < a && a < 180.0) == (orient == "bottom")
          props["labelAlign"] = Str(if left { "left" } else { "right" })
        }
        if (45.0 < a && a < 135.0) || (225.0 < a && a < 315.0) {
          props["labelBaseline"] = Str("middle")
        } else {
          let bottom = (a <= 45.0 || 315.0 <= a) == (orient == "top")
          props["labelBaseline"] = Str(if bottom { "bottom" } else { "top" })
        }
      } else {
        if (a + 90.0) % 180.0 == 0.0 {
          props["labelAlign"] = Str("center")
        } else {
          let left = (90.0 < a && a < 270.0) == (orient == "left")
          props["labelAlign"] = Str(if left { "left" } else { "right" })
        }
        if !(a <= 45.0 || 315.0 <= a || (135.0 <= a && a <= 225.0)) {
          let top = (45.0 <= a && a <= 135.0) == (orient == "left")
          props["labelBaseline"] = Str(if top { "top" } else { "bottom" })
        }
      }
    }
  }
}

///|
/// vega-lite's default `tickCount` of a continuous position axis.
fn tick_count_of(p : Pos?, size : Double) -> Double {
  match p {
    Some(q) =>
      if is_log(q) {
        10.0
      } else if q.def.bin is Some(_) {
        ceil(size / 10.0)
      } else {
        match q.time_unit {
          Some("month") | Some("hours") | Some("day") | Some("quarter") => 10.0
          _ => ceil(size / 40.0)
        }
      }
    None => ceil(size / 40.0)
  }
}

///|
/// Bars over a time unit span from the unit's start to its end.
fn is_ranged(mark : String, p : Pos) -> Bool {
  mark == "bar" &&
  ((p.temporal && p.time_unit is Some(_)) || p.def.bin is Some(_))
}

///|
fn orient_or_vertical(o : String) -> String {
  if o == "" {
    "vertical"
  } else {
    o
  }
}

///|
/// The string a text mark shows for a row.
fn text_of(
  r : Map[String, @value.Value],
  p : Pos?,
) -> String raise CompileError {
  match p {
    None => ""
    Some(q) => {
      let v = @value.get_field(r, q.field)
      match q.def.format {
        Some(f) =>
          (@format.format(f) catch {
            _ => raise CompileError("text.format 无效: " + f)
          })(v.to_number())
        None => v.to_js_string()
      }
    }
  }
}

///|
/// Titles of a range channel and its second channel, joined unless equal.
fn merge_titles(a : String, b : String) -> String {
  if a == b {
    a
  } else {
    a + ", " + b
  }
}

///|
/// vega-lite's default of the `zero` scale property for a position channel.
fn zero_of_chan(
  mark : String,
  orient : String,
  chan : String,
  secondary : Bool,
  config_zero : Bool,
) -> Bool {
  let perpendicular = (mark == "bar" || mark == "area" || mark == "line") &&
    (
      (orient == "horizontal" && chan == "y") ||
      (orient == "vertical" && chan == "x")
    )
  if perpendicular {
    false
  } else if (mark == "bar" || mark == "area") && !secondary {
    true
  } else {
    config_zero
  }
}

///|
fn is_log(p : Pos) -> Bool {
  match p.def.scale {
    Some(m) =>
      match m.get("type") {
        Some(Str("log")) => true
        _ => false
      }
    None => false
  }
}

///|
/// Half the bandwidth of a band scale (a path mark through the centre of its
/// band); 0 for point and continuous scales.
fn band_half(s : (RScale, Array[@value.Value])?) -> Double {
  match s {
    Some((sc, _)) => sc.bandwidth() * 0.5
    None => 0.0
  }
}

///|
/// vega-lite gives point-like marks an opacity of 0.7 unless the unit
/// aggregates a field.
fn has_default_opacity(mark : String, spec : @spec.Spec) -> Bool {
  (mark == "point" || mark == "circle" || mark == "square" || mark == "tick") &&
  !spec.encoding.any(fn(e) { e.1.aggregate is Some(_) })
}
