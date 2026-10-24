// Axis generation: vega-parser `axis.js` and `guides/axis-*.js` evaluated
// directly (the signals they reference are known once the view is sized),
// followed by the axis layout of vega-view-transforms.

///|
/// What the compiler decided for one axis.
pub(all) struct AxisPlan {
  scale : RScale
  /// domain values of a band / point scale, in order
  domain : Array[@value.Value]
  orient : String
  title : String?
  /// explicit axis properties (`grid`, `labelAngle`, `tickCount`, ...)
  props : Map[String, @value.Value]
  /// the scale whose range the grid lines span
  grid_scale : RScale?
  /// number of ticks wanted (already resolved, e.g. `ceil(height/40)`)
  tick_count : Double
}

///|
pub(all) struct Axis {
  mark : @scene.Mark
  orient : String
  has_grid : Bool
  has_ticks : Bool
  has_labels : Bool
  has_domain : Bool
  has_title : Bool
  /// label overlap removal: "parity" or "greedy"
  overlap : String?
  overlap_separation : Double
}

///|
fn is_x_orient(orient : String) -> Bool {
  orient == "top" || orient == "bottom"
}

// ---- configuration defaults (vega-parser/src/config.js) ----

///|
fn axis_default(name : String, band : Bool) -> @value.Value {
  match name {
    "minExtent" => Num(0.0)
    "maxExtent" => Num(200.0)
    "bandPosition" => Num(0.5)
    "domain" => Bool(true)
    "domainWidth" => Num(1.0)
    "domainColor" => Str("#888")
    "grid" => Bool(false)
    "gridWidth" => Num(1.0)
    "gridColor" => Str("#ddd")
    "labels" => Bool(true)
    "labelAngle" => Num(0.0)
    "labelLimit" => Num(180.0)
    "labelOffset" => Num(0.0)
    "labelPadding" => Num(2.0)
    "ticks" => Bool(true)
    "tickColor" => Str("#888")
    "tickOffset" => Num(if band { -0.5 } else { 0.0 })
    "tickRound" => Bool(true)
    "tickSize" => Num(5.0)
    "tickWidth" => Num(1.0)
    "titlePadding" => Num(4.0)
    _ => Undef
  }
}

///|
/// `value(spec[name], value(config[name], dflt))`
fn AxisPlan::lookup(self : AxisPlan, name : String) -> @value.Value {
  match self.props.get(name) {
    Some(Null) | Some(Undef) | None =>
      axis_default(
        name,
        match self.scale {
          Band(b) => !b.is_point
          _ => false
        },
      )
    Some(v) => v
  }
}

///|
/// A property that may be a `{condition: {test, value}, value}` object,
/// evaluated against one tick (`datum.value`, `datum.label`, `datum.index`).
fn AxisPlan::tick_prop(
  self : AxisPlan,
  name : String,
  t : Tick,
) -> @value.Value raise CompileError {
  match self.lookup(name) {
    Obj(m) if m.contains("condition") => {
      let datum : Map[String, @value.Value] = Map([])
      datum["value"] = t.value
      datum["label"] = Str(t.label)
      datum["index"] = Num(t.index)
      let conds = match m.get("condition") {
        Some(Arr(a)) => a
        Some(o) => [o]
        None => []
      }
      for c in conds {
        match c {
          Obj(cm) =>
            match cm.get("test") {
              Some(Str(src)) => {
                let ast = @expr.parse_expr(src) catch {
                  @expr.ExprError(e) =>
                    raise CompileError(name + ".condition.test: " + e)
                }
                let r = @expr.eval_expr(ast, Obj(datum)) catch {
                  @expr.ExprError(e) =>
                    raise CompileError(name + ".condition.test: " + e)
                }
                if r.truthy() {
                  return match cm.get("value") {
                    Some(v) => v
                    None => Undef
                  }
                }
              }
              _ =>
                raise CompileError(
                  "axis." + name + ".condition.test 暂不支持",
                )
            }
          _ => ()
        }
      }
      match m.get("value") {
        Some(v) => v
        None => Undef
      }
    }
    v => v
  }
}

///|
fn AxisPlan::flag(self : AxisPlan, name : String) -> Bool {
  self.lookup(name).truthy()
}

///|
fn AxisPlan::number(self : AxisPlan, name : String, dflt : Double) -> Double {
  match self.lookup(name) {
    Null | Undef => dflt
    v => v.to_number()
  }
}

///|
/// The explicit value of an optional string property.
fn AxisPlan::opt_str(self : AxisPlan, name : String) -> String? {
  match self.lookup(name) {
    Null | Undef => None
    v => Some(v.to_js_string())
  }
}

// ---- ticks ----

///|
priv struct Tick {
  value : @value.Value
  label : String
  index : Double
}

///|
fn lerp_range(r : (Double, Double), t : Double) -> Double {
  let (lo, hi) = r
  if t == 0.0 {
    lo
  } else if t == 1.0 {
    hi
  } else {
    lo + t * (hi - lo)
  }
}

///|
/// vega `flush(range, value, threshold, left, right, center)`: -1 for left,
/// 1 for right, 0 for center.
fn flush(range : (Double, Double), value : Double, t : Double?) -> Int32 {
  match t {
    None => 0
    Some(t) => {
      let mut a = range.0
      let mut b = range.1
      if b < a {
        let l = a
        a = b
        b = l
      }
      let l = (value - a).abs()
      let r = (b - value).abs()
      if l < r && l <= t {
        -1
      } else if r <= t {
        1
      } else {
        0
      }
    }
  }
}

///|
fn AxisPlan::effective_count(
  self : AxisPlan,
  d0 : Double,
  d1 : Double,
) -> Double {
  match self.props.get("tickMinStep") {
    Some(Num(step)) => {
      let q = (d1 - d0) / step
      let q = if q.is_nan() || q == 0.0 { 1.0 } else { q }
      min(self.tick_count, q.floor() + 1.0)
    }
    _ => self.tick_count
  }
}

///|
fn AxisPlan::ticks(self : AxisPlan) -> Array[Tick] raise CompileError {
  let spec = self.opt_str("format")
  match self.scale {
    Band(_) => {
      let out : Array[Tick] = []
      let as_time = self.opt_str("formatType") == Some("time")
      for v in self.domain {
        let label = match spec {
          None => v.to_js_string()
          Some(f) =>
            if as_time {
              @time.utc_format(f)(v.to_number())
            } else {
              (@format.format(f) catch {
                _ => raise CompileError("axis.format 无效: " + f)
              })(v.to_number())
            }
        }
        out.push({ value: v, label, index: 0.0, })
      }
      out
    }
    Binned(c, bins) => {
      let d0 = c.domain[0]
      let d1 = c.domain[c.domain.length() - 1]
      let count = max(self.tick_count, bins.length().to_double())
      let fmt = @format.format_span(d0, d1, count, specifier?=spec) catch {
        _ => raise CompileError("axis.format 无效")
      }
      valid_ticks(c, bins, count).map(fn(x) {
        { value: Num(x), label: fmt(x), index: 0.0, }
      })
    }
    Time(c) => {
      let d0 = c.domain[0]
      let d1 = c.domain[c.domain.length() - 1]
      let fmt = match spec {
        Some(f) => @time.utc_format(f)
        None => @time.utc_multi_format()
      }
      @time.utc_ticks(d0, d1, self.effective_count(d0, d1)).map(fn(x) {
        { value: Num(x), label: fmt(x), index: 0.0, }
      })
    }
    Cont(c) => {
      let d0 = c.domain[0]
      let d1 = c.domain[c.domain.length() - 1]
      let fmt = @format.format_span(d0, d1, self.tick_count, specifier?=spec) catch {
        _ => raise CompileError("axis.format 无效")
      }
      c
      .ticks(count=self.tick_count)
      .map(fn(x) { { value: Num(x), label: fmt(x), index: 0.0, } })
    }
  }
}

// ---- construction ----

///|
fn text_item(
  props : Array[(String, @value.Value)],
  style : String,
) -> @scene.Item {
  // the `guide-label` / `guide-title` styles of the default config
  let base = [("fill", str("#000")), ("font", str("sans-serif"))]
  let size = if style == "guide-title" { 11.0 } else { 10.0 }
  let all = base + [("fontSize", num(size))]
  let it = mk_item(all)
  if style == "guide-title" {
    it.set_str("fontWeight", "bold")
  }
  for p in props {
    it.set(p.0, p.1)
  }
  it
}

///|
fn guide_mark(
  marktype : @scene.MarkType,
  role : String,
  items : Array[@scene.Item],
) -> @scene.Mark {
  @scene.Mark::new(marktype, role~, interactive=false, items~)
}

///|
fn build_axis(
  plan : AxisPlan,
  width : Double,
  height : Double,
) -> Axis raise CompileError {
  let orient = plan.orient
  let horizontal = is_x_orient(orient)
  let has_grid = plan.flag("grid")
  let has_ticks = plan.flag("ticks")
  let has_labels = plan.flag("labels")
  let has_domain = plan.flag("domain")
  let has_title = plan.title is Some(_)
  let raw_ticks = plan.ticks()
  let n_ticks = raw_ticks.length().to_double()
  let ticks = raw_ticks.mapi(fn(i, t) {
    {
      ..t,
      index: i.to_double() /
      (if n_ticks - 1.0 == 0.0 { 1.0 } else { n_ticks - 1.0 }),
    }
  })
  let range = plan.scale.range_ends()
  let round_pos = plan.flag("tickRound")
  let tick_offset = plan.number("tickOffset", 0.0)
  let band_pos = plan.number("bandPosition", 0.5)
  let bw = plan.scale.bandwidth()
  let children : Array[@scene.Mark] = []
  // position of a tick along the axis: scale(value) [+ bandwidth * band] + offset
  let pos = fn(
    v : @value.Value,
    band : Double,
    offset : Double,
    round_it : Bool,
  ) {
    let p = match plan.scale.map(v) {
      Some(x) => x
      None => @double.not_a_number
    }
    let r = p + bw * band + offset
    if round_it {
      round(r)
    } else {
      r
    }
  }
  if has_grid {
    let sign = if orient == "left" || orient == "top" { 1.0 } else { -1.0 }
    let (start, end) = match plan.grid_scale {
      Some(gs) => {
        let gr = gs.range_ends()
        (lerp_range(gr, 0.0) * sign + 0.0, lerp_range(gr, 1.0) * sign + 0.0)
      }
      None => (0.0, (if horizontal { height } else { width }) * sign + 0.0)
    }
    let items = ticks.map(fn(t) raise CompileError {
      let p = pos(t.value, band_pos, tick_offset, round_pos)
      let it = mk_item([
        ("opacity", num(1.0)),
        ("stroke", plan.tick_prop("gridColor", t)),
        ("strokeWidth", plan.tick_prop("gridWidth", t)),
      ])
      if horizontal {
        it.set_num("x", p)
        it.set_num("y", start)
        it.set_num("y2", end)
      } else {
        it.set_num("y", p)
        it.set_num("x", start)
        it.set_num("x2", end)
      }
      it
    })
    children.push(guide_mark(Rule, "axis-grid", items))
  }
  let size = plan.number("tickSize", 5.0)
  let tick_sign = if orient == "left" || orient == "top" { -1.0 } else { 1.0 }
  if has_ticks {
    let items = ticks.map(fn(t) raise CompileError {
      let p = pos(t.value, band_pos, tick_offset, round_pos)
      let it = mk_item([
        ("opacity", num(1.0)),
        ("stroke", plan.tick_prop("tickColor", t)),
        ("strokeWidth", plan.tick_prop("tickWidth", t)),
      ])
      if horizontal {
        it.set_num("y", 0.0)
        it.set_num("y2", size * tick_sign)
        it.set_num("x", p)
      } else {
        it.set_num("x", 0.0)
        it.set_num("x2", size * tick_sign)
        it.set_num("y", p)
      }
      it
    })
    children.push(guide_mark(Rule, "axis-tick", items))
  }
  if has_labels {
    let label_size = if has_ticks { size } else { 0.0 }
    let pad = plan.number("labelPadding", 0.0)
    let edge = label_size * tick_sign + pad * tick_sign
    let label_offset = plan.number("labelOffset", 0.0)
    let flush_t : Double? = match plan.lookup("labelFlush") {
      Undef | Null | Bool(false) => None
      v => Some(v.to_number())
    }
    let items = ticks.map(fn(t) raise CompileError {
      let p = pos(t.value, 0.5, tick_offset + label_offset, false)
      let it = text_item(
        [
          ("opacity", num(1.0)),
          ("angle", plan.lookup("labelAngle")),
          ("limit", plan.lookup("labelLimit")),
          ("text", str(t.label)),
        ],
        "guide-label",
      )
      let sv = match plan.scale.map(t.value) {
        Some(v) => v
        None => @double.not_a_number
      }
      let flushed = flush(range, sv, flush_t)
      if horizontal {
        it.set_num("x", p)
        it.set_num("y", edge)
        it.set_str(
          "align",
          match flushed {
            -1 => "left"
            1 => "right"
            _ => "center"
          },
        )
        it.set_str("baseline", if orient == "top" { "bottom" } else { "top" })
      } else {
        it.set_num("y", p)
        it.set_num("x", edge)
        it.set_str("align", if orient == "right" { "left" } else { "right" })
        it.set_str(
          "baseline",
          match flushed {
            -1 => "top"
            1 => "bottom"
            _ => "middle"
          },
        )
      }
      match plan.opt_str("labelAlign") {
        Some(a) => it.set_str("align", a)
        None => ()
      }
      match plan.opt_str("labelBaseline") {
        Some(b) => it.set_str("baseline", b)
        None => ()
      }
      match plan.tick_prop("labelColor", t) {
        Undef | Null => ()
        c => it.set("fill", c)
      }
      match plan.tick_prop("labelFontSize", t) {
        Undef | Null => ()
        c => it.set("fontSize", c)
      }
      it
    })
    children.push(guide_mark(Text, "axis-label", items))
  }
  if has_domain {
    let it = mk_item([
      ("opacity", num(1.0)),
      ("stroke", plan.lookup("domainColor")),
      ("strokeWidth", plan.lookup("domainWidth")),
    ])
    if horizontal {
      it.set_num("x", lerp_range(range, 0.0))
      it.set_num("x2", lerp_range(range, 1.0))
      it.set_num("y", 0.0)
    } else {
      it.set_num("y", lerp_range(range, 0.0))
      it.set_num("y2", lerp_range(range, 1.0))
      it.set_num("x", 0.0)
    }
    children.push(guide_mark(Rule, "axis-domain", [it]))
  }
  match plan.title {
    Some(title) => {
      let t_sign = if orient == "left" || orient == "top" { -1.0 } else { 1.0 }
      let it = text_item(
        [
          ("opacity", num(1.0)),
          ("anchor", Null),
          ("align", str("center")),
          ("auto", boolean(true)),
          ("text", str(title)),
        ],
        "guide-title",
      )
      let mid = lerp_range(range, 0.5)
      if horizontal {
        it.set_num("x", mid)
        it.set_num("angle", 0.0)
        it.set_str("baseline", if orient == "top" { "bottom" } else { "top" })
      } else {
        it.set_num("y", mid)
        it.set_num("angle", t_sign * 90.0)
        it.set_str("baseline", "bottom")
      }
      children.push(guide_mark(Text, "axis-title", [it]))
    }
    None => ()
  }
  let item = mk_item([
    ("orient", str(orient)),
    ("offset", num(plan.number("offset", 0.0))),
    ("position", num(plan.number("position", 0.0))),
    ("titlePadding", num(plan.number("titlePadding", 0.0))),
    ("minExtent", num(plan.number("minExtent", 0.0))),
    ("maxExtent", num(plan.number("maxExtent", 0.0))),
    ("range", num((range.1 - range.0).abs())),
  ])
  for c in children {
    item.children.push(c)
  }
  match plan.props.get("format") {
    Some(Str(f)) => {
      item.set_str("format", f)
      match plan.props.get("formatType") {
        Some(Str(t)) => item.set_str("formatType", t)
        _ => ()
      }
    }
    _ => ()
  }
  let mark = @scene.Mark::new(
    Group,
    role="axis",
    interactive=false,
    aria=plan.flag("aria") || !plan.props.contains("aria"),
    items=[item],
  )
  let overlap = match plan.lookup("labelOverlap") {
    Bool(true) => Some("parity")
    Str(m) => Some(m)
    _ => None
  }
  {
    mark,
    orient,
    has_grid,
    has_ticks,
    has_labels,
    has_domain,
    has_title,
    overlap,
    overlap_separation: plan.number("labelSeparation", 0.0),
  }
}

// ---- layout ----

///|
/// vega-view-transforms `axisLayout`: position the axis group and its title,
/// returning the bounds the axis occupies in the view.
fn axis_layout(ax : Axis, width : Double, height : Double) -> @scene.Bounds {
  let item = ax.mark.items[0]
  let delta = item.num_or("translate", 0.5)
  let range = item.num0("range")
  let offset = item.num0("offset")
  let position = item.num0("position")
  let min_extent = item.num0("minExtent")
  let max_extent = item.num0("maxExtent")
  let title_padding = item.num0("titlePadding")
  let bounds = item.bounds
  // child indices: grid, ticks, labels, domain, title (those present)
  let mut index = 0
  let grid = if ax.has_grid {
    index += 1
    Some(item.children[index - 1])
  } else {
    None
  }
  let ticks = if ax.has_ticks {
    index += 1
    Some(item.children[index - 1])
  } else {
    None
  }
  let labels = if ax.has_labels {
    index += 1
    Some(item.children[index - 1])
  } else {
    None
  }
  let title_mark = if ax.has_title {
    Some(item.children[index + (if ax.has_domain { 1 } else { 0 })])
  } else {
    None
  }
  let title = match title_mark {
    Some(m) => Some(m.items[0])
    None => None
  }
  ignore(bounds.clear())
  // vega unions the tick and label marks (indices 0 and 1 among grid, ticks)
  let _ = grid
  match ticks {
    Some(m) => ignore(bounds.union(m.bounds))
    None => ()
  }
  match labels {
    Some(m) => ignore(bounds.union(m.bounds))
    None => ()
  }
  let mut x = 0.0
  let mut y = 0.0
  let dl = match title {
    Some(t) => @scene.multi_line_offset(t)
    None => 0.0
  }
  match ax.orient {
    "top" => {
      x = position
      y = -offset
      let s = max(min_extent, min(max_extent, -bounds.y1))
      ignore(bounds.add(0.0, -s).add(range, 0.0))
      axis_title_layout(
        title, title_mark, s, title_padding, dl, false, -1.0, bounds,
      )
    }
    "left" => {
      x = -offset
      y = position
      let s = max(min_extent, min(max_extent, -bounds.x1))
      ignore(bounds.add(-s, 0.0).add(0.0, range))
      axis_title_layout(
        title, title_mark, s, title_padding, dl, true, -1.0, bounds,
      )
    }
    "right" => {
      x = width + offset
      y = position
      let s = max(min_extent, min(max_extent, bounds.x2))
      ignore(bounds.add(0.0, 0.0).add(s, range))
      axis_title_layout(
        title, title_mark, s, title_padding, dl, true, 1.0, bounds,
      )
    }
    _ => {
      x = position
      y = height + offset
      let s = max(min_extent, min(max_extent, bounds.y2))
      ignore(bounds.add(0.0, 0.0).add(range, s))
      axis_title_layout(
        title, title_mark, s, title_padding, 0.0, false, 1.0, bounds,
      )
    }
  }
  ignore(@scene.bound_stroke(bounds.translate(x, y), item))
  item.set_num("x", x + delta)
  item.set_num("y", y + delta)
  ax.mark.bounds.clear().union(bounds)
}

///|
fn axis_title_layout(
  title : @scene.Item?,
  title_mark : @scene.Mark?,
  offset : Double,
  pad : Double,
  dl : Double,
  is_y : Bool,
  sign : Double,
  bounds : @scene.Bounds,
) -> Unit {
  match (title, title_mark) {
    (Some(t), Some(m)) => {
      let b = t.bounds
      if t.truthy("auto") {
        let v = sign * (offset + dl + pad)
        let mut dx = 0.0
        let mut dy = 0.0
        if is_y {
          dx = t.num0("x") - v
          t.set_num("x", v)
        } else {
          dy = t.num0("y") - v
          t.set_num("y", v)
        }
        ignore(m.bounds.clear().union(b.translate(-dx, -dy)))
      }
      ignore(bounds.union(b))
    }
    _ => ()
  }
}

// ---- label overlap (vega-view-transforms `Overlap`) ----

///|
fn bounds_intersect(a : @scene.Bounds, b : @scene.Bounds, sep : Double) -> Bool {
  sep > max(max(b.x1 - a.x2, a.x1 - b.x2), max(b.y1 - a.y2, a.y1 - b.y2))
}

///|
fn has_overlap(items : Array[@scene.Item], pad : Double) -> Bool {
  for i in 1..<items.length() {
    if bounds_intersect(items[i - 1].bounds, items[i].bounds, pad) {
      return true
    }
  }
  false
}

///|
fn remove_overlap(mark : @scene.Mark, how : String, sep : Double) -> Unit {
  let source = mark.items.filter(fn(it) {
    it.bounds.width() > 1.0 && it.bounds.height() > 1.0
  })
  if source.length() == 0 {
    return
  }
  for it in source {
    it.set_num("opacity", 1.0)
  }
  let mut items = source
  if items.length() >= 3 && has_overlap(items, sep) {
    while true {
      if how == "greedy" {
        let kept : Array[@scene.Item] = []
        let mut a = items[0]
        for i in 0..<items.length() {
          let b = items[i]
          if i == 0 || !bounds_intersect(a.bounds, b.bounds, sep) {
            a = b
            kept.push(b)
          } else {
            b.set_num("opacity", 0.0)
          }
        }
        items = kept
      } else {
        let kept : Array[@scene.Item] = []
        for i in 0..<items.length() {
          if i % 2 == 1 {
            items[i].set_num("opacity", 0.0)
          } else {
            kept.push(items[i])
          }
        }
        items = kept
      }
      if !(items.length() >= 3 && has_overlap(items, sep)) {
        break
      }
    }
    let last = source[source.length() - 1]
    if items.length() < 3 && !last.truthy("opacity") {
      if items.length() > 1 {
        items[items.length() - 1].set_num("opacity", 0.0)
      }
      last.set_num("opacity", 1.0)
    }
  }
  ignore(mark.bounds.clear())
  for it in source {
    if it.truthy("opacity") {
      ignore(mark.bounds.union(it.bounds))
    }
  }
}

///|
/// Compute the bounds of an axis group: children first, labels de-overlapped,
/// then the group item itself.
fn bound_axis(ax : Axis) -> Unit raise CompileError {
  let item = ax.mark.items[0]
  try {
    for child in item.children {
      @scene.bound_mark(child)
      if child.role == Some("axis-label") {
        match ax.overlap {
          Some(m) => remove_overlap(child, m, ax.overlap_separation)
          None => ()
        }
      }
    }
  } catch {
    @scene.SceneError(m) => raise CompileError(m)
  }
  ignore(ax.mark.bounds.clear())
  ignore(item.bounds.clear())
  ignore(@scene.bound_group(item.bounds, item))
  ignore(ax.mark.bounds.union(item.bounds))
}

///|
/// vega-scale `validTicks`: keep candidate ticks inside the range, in range
/// order, and thin them out to at most `count`.
fn valid_ticks(
  c : @scale.Continuous,
  candidates : Array[Double],
  count : Double,
) -> Array[Double] {
  let r0 = c.range[0]
  let r1 = c.range[c.range.length() - 1]
  let reversed = r0 > r1
  let lo = (if reversed { r1 } else { r0 }).floor()
  let hi = (if reversed { r0 } else { r1 }).ceil()
  let pairs : Array[(Double, Double)] = []
  for v in candidates {
    match c.map(v) {
      Some(s) => if lo <= s && s <= hi { pairs.push((v, s)) }
      None => ()
    }
  }
  let sorted = @transform.stable_sort(pairs, fn(a, b) {
    let d = if reversed { b.1 - a.1 } else { a.1 - b.1 }
    if d < 0.0 {
      -1
    } else if d > 0.0 {
      1
    } else {
      0
    }
  })
  let mut ticks = sorted.map(fn(p) { p.0 })
  if count > 0.0 && ticks.length() > 1 {
    let endpoints = [ticks[0], ticks[ticks.length() - 1]]
    while ticks.length().to_double() > count && ticks.length() >= 3 {
      let kept : Array[Double] = []
      for i in 0..<ticks.length() {
        if i % 2 == 0 {
          kept.push(ticks[i])
        }
      }
      ticks = kept
    }
    if ticks.length() < 3 {
      ticks = endpoints
    }
  }
  ticks
}
