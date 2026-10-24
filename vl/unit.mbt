// Compilation of a single-view specification with x / y position channels.

///|
/// A position channel with everything resolved from its definition.
priv struct Pos {
  chan : String
  def : @spec.ChannelDef
  typ : String
  /// the data field this channel reads after the data pipeline
  field : String
  title : String
  discrete : Bool
  temporal : Bool
  aggregate : String?
}

///|
fn derived_field(def : @spec.ChannelDef) -> String raise CompileError {
  match (def.aggregate, def.field) {
    (Some("count"), _) => "__count"
    (Some(op), Some(f)) => op + "_" + f
    (None, Some(f)) => f
    _ => raise CompileError("channel 缺少 field")
  }
}

///|
/// `titleCase`: upper-case the first character.
fn capitalize(s : String) -> String {
  if s.length() == 0 {
    s
  } else {
    s[0:1].to_upper().to_string() + s[1:].to_string()
  }
}

///|
fn default_title(def : @spec.ChannelDef) -> String raise CompileError {
  match (def.aggregate, def.field) {
    (Some("count"), _) => "Count of Records"
    (Some(op), Some(f)) => capitalize(op) + " of " + f
    (None, Some(f)) => f
    _ => raise CompileError("channel 缺少 field")
  }
}

///|
fn resolve_pos(chan : String, def : @spec.ChannelDef) -> Pos raise CompileError {
  let typ = match def.typ {
    Some(t) => t
    None => if def.aggregate is Some(_) { "quantitative" } else { "nominal" }
  }
  let title = match def.title {
    Some(Some(t)) => t
    _ => default_title(def)
  }
  {
    chan,
    def,
    typ,
    field: derived_field(def),
    title,
    discrete: typ == "nominal" || typ == "ordinal",
    temporal: typ == "temporal",
    aggregate: def.aggregate,
  }
}

///|
fn config_number(v : @value.Value?, dflt : Double) -> Double {
  match v {
    Some(Num(x)) => x
    _ => dflt
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
fn domain_extent(
  rows : Array[Map[String, @value.Value]],
  fields : Array[String],
  zero : Bool,
) -> (Double, Double)? {
  let mut lo = @double.infinity
  let mut hi = @double.neg_infinity
  for f in fields {
    match @transform.extent(rows, f) {
      Some((a, b)) => {
        lo = min(lo, a)
        hi = max(hi, b)
      }
      None => ()
    }
  }
  if lo > hi {
    return None
  }
  if zero {
    lo = min(lo, 0.0)
    hi = max(hi, 0.0)
  }
  Some((lo, hi))
}

///|
/// The scale of a position channel; `size` is the view size along it (None
/// for a discrete scale whose size follows from its step).
fn pos_scale(
  p : Pos,
  rows : Array[Map[String, @value.Value]],
  domain_fields : Array[String],
  mark : String,
  range_start : Double,
  range_stop : Double,
) -> (RScale, Array[@value.Value]) {
  if p.discrete {
    let domain = sorted_unique(rows, p.field)
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
    match domain_extent(rows, domain_fields, false) {
      Some((lo, hi)) => c.domain = [lo, hi]
      None => ()
    }
    c.range = [range_start, range_stop]
    (Time(c), [])
  } else {
    let zero = match mark {
      "bar" | "area" => true
      _ => true
    }
    let c = @scale.Continuous::new(Linear)
    match domain_extent(rows, domain_fields, zero) {
      Some((lo, hi)) => c.domain = [lo, hi]
      None => ()
    }
    c.range = [range_start, range_stop]
    c.nice()
    (Cont(c), [])
  }
}

///|
pub fn compile(text : String) -> Compiled raise CompileError {
  let spec = @spec.parse_spec_text(text) catch { e => raise spec_err(e) }
  let source = match spec.data {
    Some(d) => d
    None => raise CompileError("data 缺失")
  }
  let mark = spec.mark.typ
  if mark != "bar" &&
    mark != "point" &&
    mark != "tick" &&
    mark != "line" &&
    mark != "circle" &&
    mark != "square" {
    raise CompileError("mark " + mark + " 暂不支持")
  }
  let mut rows = source.map(fn(r) { r.copy() })
  // temporal fields are parsed to dates (vega `toDate`)
  for d in [find_channel(spec, "x"), find_channel(spec, "y")] {
    match d {
      Some({ typ: Some("temporal"), field: Some(f), aggregate: None, .. }) =>
        for r in rows {
          r[f] = @value.get_field(r, f).coerce_date()
        }
      _ => ()
    }
  }
  // user transforms
  for t in spec.transform {
    match t {
      Filter(Expr(src)) =>
        rows = @transform.filter(rows, src) catch {
          @transform.TransformError(m) => raise CompileError(m)
        }
      _ => raise CompileError("transform 暂不支持")
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
  // encoding-level aggregates
  let measures : Array[@transform.Measure] = []
  let groupby : Array[String] = []
  for p in positions {
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
      None => groupby.push(p.field)
    }
  }
  let has_aggregate = measures.length() > 0
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
  let vertical = orient != "horizontal"
  ignore(x_cont)
  ignore(y_cont)
  // stacking: bars with an unaggregated continuous field
  let stack_chan : String? = if mark == "bar" && !has_aggregate {
    match (px, py) {
      (Some(x), Some(y)) =>
        if x.discrete && !y.discrete {
          Some("y")
        } else if y.discrete && !x.discrete {
          Some("x")
        } else {
          None
        }
      _ => None
    }
  } else {
    None
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
        None,
        "zero",
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
  let is_path = mark == "line" || mark == "area"
  let data = if is_path {
    rows
  } else {
    rows.filter(fn(r) {
      valid_fields.all(fn(f) { is_finite_valid(@value.get_field(r, f)) })
    })
  }
  // view sizes
  let xstep = step_of(spec.width)
  let ystep = step_of(spec.height)
  let width_of = fn(
    p : Pos?,
    step : Double?,
    dflt : Double,
    spec_size : @value.Value?,
  ) -> Double {
    match p {
      Some(q) if q.discrete => {
        let n = sorted_unique(data, q.field).length().to_double()
        let (pi, po) = if mark == "bar" {
          (0.1, 0.05)
        } else if mark == "tick" {
          (0.25, 0.125)
        } else {
          (1.0, 0.5)
        }
        let s = match step {
          Some(v) => v
          None => 20.0
        }
        if mark == "bar" || mark == "tick" {
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
  let width = width_of(px, xstep, 200.0, spec.width)
  let height = width_of(py, ystep, 200.0, spec.height)
  // scales
  let xfields = match px {
    Some(p) =>
      if stack_chan == Some("x") {
        [p.field + "_start", p.field + "_end"]
      } else {
        [p.field]
      }
    None => []
  }
  let yfields = match py {
    Some(p) =>
      if stack_chan == Some("y") {
        [p.field + "_start", p.field + "_end"]
      } else {
        [p.field]
      }
    None => []
  }
  let xs = match px {
    Some(p) => Some(pos_scale(p, data, xfields, mark, 0.0, width))
    None => None
  }
  let ys = match py {
    Some(p) =>
      if p.discrete {
        Some(pos_scale(p, data, yfields, mark, 0.0, height))
      } else {
        Some(pos_scale(p, data, yfields, mark, height, 0.0))
      }
    None => None
  }
  // axes
  let axes : Array[Axis] = []
  let tick_x = ceil(width / 40.0)
  let tick_y = ceil(height / 40.0)
  let grid_props = fn(axis : @spec.Guide) -> Map[String, @value.Value] {
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
    m
  }
  match (px, xs, ys) {
    (Some(p), Some((s, _)), _) =>
      if !p.discrete {
        match ys {
          Some((gs, _)) =>
            axes.push(
              build_axis(
                {
                  scale: s,
                  domain: [],
                  orient: "bottom",
                  title: None,
                  props: grid_props(p.def.axis),
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
                  orient: "bottom",
                  title: None,
                  props: grid_props(p.def.axis),
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
      if !p.discrete {
        axes.push(
          build_axis(
            {
              scale: s,
              domain: [],
              orient: "left",
              title: None,
              props: grid_props(p.def.axis),
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
        if p.def.axis is Default {
          props["labelAngle"] = Num(270.0)
          props["labelAlign"] = Str("right")
          props["labelBaseline"] = Str("middle")
        }
      } else {
        props["labelFlush"] = Bool(true)
        props["labelOverlap"] = Bool(true)
      }
      apply_axis_spec(props, p.def.axis)
      axes.push(
        build_axis(
          {
            scale: s,
            domain: d,
            orient: "bottom",
            title: Some(p.title),
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
      if !p.discrete {
        props["labelOverlap"] = Bool(true)
      }
      apply_axis_spec(props, p.def.axis)
      axes.push(
        build_axis(
          {
            scale: s,
            domain: d,
            orient: "left",
            title: Some(p.title),
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
  // marks
  let color = mark_color(spec)
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
        let it = mk_item([("fill", str(color))])
        let px_ = px.unwrap()
        let py_ = py.unwrap()
        if vertical {
          it.set_num("x", pos_of(xs, r, px_.field))
          it.set_num("width", max(0.25, xs.unwrap().0.bandwidth()))
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
        let it = mk_item([("strokeWidth", num(2.0)), ("stroke", str(color))])
        it.set_num("x", pos_of(xs, r, px.unwrap().field))
        it.set_num("y", pos_of(ys, r, py.unwrap().field))
        it.set(
          "defined",
          Bool(
            valid_fields.all(fn(f) { is_finite_valid(@value.get_field(r, f)) }),
          ),
        )
        items.push(it)
      }
      "tick" => {
        let it = mk_item([("opacity", num(0.7)), ("fill", str(color))])
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
          ("opacity", num(0.7)),
        ])
        if filled {
          it.set_str("fill", color)
        } else {
          it.set_str("fill", "transparent")
          it.set_str("stroke", color)
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
        items.push(it)
      }
    }
  }
  let mt = match mark {
    "point" | "circle" | "square" => @scene.MarkType::Symbol
    "line" => @scene.MarkType::Line
    _ => @scene.MarkType::Rect
  }
  if mark == "line" {
    // `sort: {field: "x"}`
    let sorted = @transform.stable_sort(items, fn(a, b) {
      @value.compare_values(a.get("x"), b.get("x"))
    })
    items.clear()
    for it in sorted {
      items.push(it)
    }
  }
  let marks = @scene.Mark::new(mt, name="marks", role="mark", items~)
  assemble(spec, axes, [marks], width, height)
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
