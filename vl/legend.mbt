// Symbol legends: vega-parser `legend.js`, `legend-symbol-groups.js`,
// `legend-title.js` and the legend layout of vega-view-transforms.

///|
/// One legend entry: its label and the symbol properties that depend on the
/// value (`fill` / `stroke` / `size` / `shape` / `opacity` ...).
pub(all) struct LegendEntry {
  label : String
  props : Map[String, @value.Value]
}

///|
pub(all) struct LegendPlan {
  title : String?
  orient : String
  /// symbol properties shared by every entry (`shape`, `size`, `fill`, ...)
  symbol : Map[String, @value.Value]
  entries : Array[LegendEntry]
}

///|
pub(all) struct Legend {
  mark : @scene.Mark
  orient : String
  /// the group items of the entries and the mark holding them
  entry_items : Array[@scene.Item]
  scope_mark : @scene.Mark
  entry_mark : @scene.Mark
  title_mark : @scene.Mark?
}

///|
fn legend_item(l : Legend) -> @scene.Item {
  l.mark.items[0]
}

///|
fn legend_entry_group(l : Legend) -> @scene.Item {
  l.entry_mark.items[0]
}

///|
pub fn build_legend(plan : LegendPlan) -> Legend raise CompileError {
  let label_size = 10.0
  let size = match plan.symbol.get("size") {
    Some(Num(v)) => v
    _ => 100.0
  }
  let stroke_width = match plan.symbol.get("strokeWidth") {
    Some(Num(v)) => v
    _ => 1.5
  }
  // per-entry symbol extent: max(ceil(sqrt(size) + strokeWidth), fontSize)
  let sizes = plan.entries.map(fn(e) {
    let sz = match e.props.get("size") {
      Some(Num(v)) => v
      _ => size
    }
    max(ceil(sz.sqrt() + stroke_width), label_size)
  })
  let mut offset = 0.0
  for v in sizes {
    offset = max(offset, v)
  }
  let entry_items : Array[@scene.Item] = []
  let n = plan.entries.length()
  for i in 0..<n {
    let e = plan.entries[i]
    let sym = mk_item([("opacity", num(1.0))])
    for k, v in plan.symbol {
      sym.set(k, v)
    }
    for k, v in e.props {
      sym.set(k, v)
    }
    sym.set_num("x", offset * 0.5 + 0.0)
    sym.set_num("y", sizes[i] * 0.5)
    let label = text_item(
      [
        ("opacity", num(1.0)),
        ("x", num(offset + (0.0 + 4.0))),
        ("y", num(sizes[i] * 0.5)),
        ("align", str("left")),
        ("baseline", str("middle")),
        ("limit", num(160.0)),
        ("text", str(e.label)),
      ],
      "guide-label",
    )
    let entry = mk_item([
      ("noBound", boolean(true)),
      ("width", num(0.0)),
      ("height", num(0.0)),
      ("opacity", num(1.0)),
      ("row", num(i.to_double())),
      ("column", num(0.0)),
    ])
    entry.children.push(
      @scene.Mark::new(Symbol, role="legend-symbol", interactive=false, items=[
        sym,
      ]),
    )
    entry.children.push(
      @scene.Mark::new(Text, role="legend-label", interactive=false, items=[
        label,
      ]),
    )
    entry_items.push(entry)
  }
  let scope_mark = @scene.Mark::new(
    Group,
    role="scope",
    interactive=false,
    items=entry_items,
  )
  let entry_group = mk_item([("x", num(0.0)), ("y", num(0.0))])
  entry_group.children.push(scope_mark)
  let entry_mark = @scene.Mark::new(
    Group,
    role="legend-entry",
    interactive=false,
    items=[entry_group],
  )
  let item = mk_item([
    ("orient", str(plan.orient)),
    ("padding", num(0.0)),
    ("titlePadding", num(5.0)),
  ])
  item.children.push(entry_mark)
  let title_mark = match plan.title {
    Some(t) => {
      let it = text_item(
        [
          ("opacity", num(1.0)),
          ("orient", str("top")),
          ("text", str(t)),
          ("limit", num(180.0)),
          ("x", num(0.0)),
          ("y", num(0.0)),
          ("anchor", str("start")),
          ("angle", num(0.0)),
          ("align", str("left")),
          ("baseline", str("top")),
        ],
        "guide-title",
      )
      let m = @scene.Mark::new(Text, role="legend-title", interactive=false, items=[
        it,
      ])
      item.children.push(m)
      Some(m)
    }
    None => None
  }
  let mark = @scene.Mark::new(Group, role="legend", interactive=false, items=[
    item,
  ])
  let lg = {
    mark,
    orient: plan.orient,
    entry_items,
    scope_mark,
    entry_mark,
    title_mark,
  }
  try {
    // bound entries, lay them out in a column, then bound the legend
    @scene.bound_mark(scope_mark)
    ignore(
      grid_layout(entry_items, entry_items.map(fn(_) { scope_mark }), {
        align_col: "each",
        align_row: "each",
        pad_col: 10.0,
        pad_row: 2.0,
        columns: 1,
        center_col: false,
        center_row: true,
        flush: false,
        anchor_x: 0.0,
        anchor_y: 0.0,
        anchor_col: "",
        anchor_row: "",
      }),
    )
    ignore(entry_group.bounds.clear())
    ignore(@scene.bound_group(entry_group.bounds, entry_group))
    ignore(entry_mark.bounds.clear().union(entry_group.bounds))
    match title_mark {
      Some(m) => @scene.bound_mark(m)
      None => ()
    }
    ignore(item.bounds.clear())
    ignore(@scene.bound_group(item.bounds, item))
    ignore(mark.bounds.clear().union(item.bounds))
  } catch {
    @scene.SceneError(m) => raise CompileError(m)
  }
  lg
}

// ---- layout ----

///|
fn translate_item(
  item : @scene.Item,
  mark : @scene.Mark,
  dx : Double,
  dy : Double,
) -> Unit {
  item.set_num("x", item.num0("x") + dx)
  item.set_num("y", item.num0("y") + dy)
  ignore(item.bounds.translate(dx, dy))
  ignore(mark.bounds.translate(dx, dy))
}

///|
fn legend_title_offset(
  item : @scene.Item,
  entry : @scene.Item,
  title : @scene.Item,
  anchor : String,
  y : Bool,
  lr : Bool,
  no_bar : Bool,
) -> Double {
  ignore(lr)
  ignore(no_bar)
  let e = entry
  let s = (if y { e.bounds.y2 } else { e.bounds.x2 }) - item.num0("padding")
  let o = if !y { 0.0 } else { @scene.multi_line_offset(title) }
  match anchor {
    "start" => round(0.0)
    "end" => round(s - o)
    _ => round(0.5 * (s - o))
  }
}

///|
/// vega `legendLayout`: pad the legend, place the title and size the group.
fn legend_layout(l : Legend) -> Unit {
  let item = legend_item(l)
  let entry = legend_entry_group(l)
  let pad = item.num0("padding")
  // cache the current bounds
  item.set(
    "_bounds",
    Obj(
      Map::from_array([
        ("x1", Num(item.bounds.x1)),
        ("y1", Num(item.bounds.y1)),
        ("x2", Num(item.bounds.x2)),
        ("y2", Num(item.bounds.y2)),
      ]),
    ),
  )
  let mut ex = pad - entry.num0("x")
  let mut ey = pad - entry.num0("y")
  match l.title_mark {
    None =>
      if ex != 0.0 || ey != 0.0 {
        translate_item(entry, l.entry_mark, ex, ey)
      }
    Some(tm) => {
      let title = tm.items[0]
      let anchor = title.str("anchor").unwrap_or("start")
      let tpad = item.num0("titlePadding")
      let mut tx = pad - title.num0("x")
      let mut ty = pad - title.num0("y")
      match title.str("orient") {
        Some("left") => ex += ceil(title.bounds.width()) + tpad
        Some("right") | Some("bottom") => ()
        _ => ey += title.bounds.height() + tpad
      }
      if ex != 0.0 || ey != 0.0 {
        translate_item(entry, l.entry_mark, ex, ey)
      }
      match title.str("orient") {
        Some("left") =>
          ty += legend_title_offset(
            item, entry, title, anchor, true, true, false,
          )
        Some("right") => {
          tx += legend_title_offset(
              item, entry, title, "end", false, false, false,
            ) +
            tpad
          ty += legend_title_offset(
            item, entry, title, anchor, true, true, false,
          )
        }
        Some("bottom") => {
          tx += legend_title_offset(
            item, entry, title, anchor, false, false, false,
          )
          ty += legend_title_offset(
              item, entry, title, "end", true, false, true,
            ) +
            tpad
        }
        _ =>
          tx += legend_title_offset(
            item, entry, title, anchor, false, false, false,
          )
      }
      if tx != 0.0 || ty != 0.0 {
        translate_item(title, tm, tx, ty)
      }
      let t = round(title.bounds.x1 - pad)
      if t < 0.0 {
        translate_item(entry, l.entry_mark, -t, 0.0)
        translate_item(title, tm, -t, 0.0)
      }
    }
  }
  // aggregate bounds to determine the size
  let b = @scene.Bounds::new()
  ignore(b.union(l.entry_mark.bounds))
  match l.title_mark {
    Some(tm) => ignore(b.union(tm.bounds))
    None => ()
  }
  b.x1 = pad
  b.y1 = pad
  let mut w = 2.0 * pad
  let mut h = 2.0 * pad
  if !b.is_empty() {
    w = ceil(b.width() + w)
    h = ceil(b.height() + h)
  }
  // symbol entries get uniform column widths and their own height
  let widths : Map[Int32, Double] = Map([])
  for g in l.entry_items {
    let c = g.num0("column").to_int()
    let cur = match widths.get(c) {
      Some(v) => v
      None => 0.0
    }
    widths[c] = max(g.bounds.x2 - g.num0("x"), cur)
  }
  for g in l.entry_items {
    g.set_num("width", widths[g.num0("column").to_int()])
    g.set_num("height", g.bounds.y2 - g.num0("y"))
  }
  item.set_num("x", 0.0)
  item.set_num("y", 0.0)
  item.set_num("width", w)
  item.set_num("height", h)
  ignore(item.bounds.set(0.0, 0.0, w, h))
  ignore(@scene.bound_stroke(item.bounds, item))
  ignore(l.mark.bounds.clear().union(item.bounds))
}

///|
/// Place a group of legends sharing an orient next to the plot
/// (`legendParams` + `gridLayout`).
fn place_legends(
  group : Array[Legend],
  orient : String,
  xb : @scene.Bounds,
  yb : @scene.Bounds,
  width : Double,
  height : Double,
) -> Unit {
  let offset = 18.0
  let vertical = orient == "left" || orient == "right"
  let opt : GridOpt = {
    align_col: "each",
    align_row: "each",
    pad_col: 8.0,
    pad_row: 8.0,
    columns: if vertical {
      1
    } else {
      group.length()
    },
    center_col: false,
    center_row: false,
    flush: true,
    anchor_x: 0.0,
    anchor_y: 0.0,
    anchor_col: "",
    anchor_row: "start",
  }
  let o = match orient {
    "left" =>
      {
        ..opt,
        anchor_x: xb.x1.floor() - offset,
        anchor_col: "end",
        anchor_y: 0.0 *
        (if height != 0.0 { height } else { xb.height() + 2.0 * xb.y1 }),
        anchor_row: "start",
      }
    "right" =>
      {
        ..opt,
        anchor_x: ceil(xb.x2) + offset,
        anchor_y: 0.0 *
        (if height != 0.0 { height } else { xb.height() + 2.0 * xb.y1 }),
        anchor_row: "start",
      }
    "top" =>
      {
        ..opt,
        anchor_y: yb.y1.floor() - offset,
        anchor_row: "end",
        anchor_x: 0.0 *
        (if width != 0.0 { width } else { yb.width() + 2.0 * yb.x1 }),
        anchor_col: "start",
      }
    _ =>
      {
        ..opt,
        anchor_y: ceil(yb.y2) + offset,
        anchor_x: 0.0 *
        (if width != 0.0 { width } else { yb.width() + 2.0 * yb.x1 }),
        anchor_col: "start",
      }
  }
  ignore(grid_layout(group.map(legend_item), group.map(fn(l) { l.mark }), o))
}

// ---- gradient legends (continuous colour scales) ----

///|
/// A vertical gradient legend: a colour ramp with tick labels
/// (vega-parser `legend-gradient.js` and `legend-gradient-labels.js`).
pub fn build_gradient_legend(
  title : String?,
  seq : @scale.Sequential,
  length : Double,
  ramp_opacity : Double,
  label_format : String?,
) -> Legend raise CompileError {
  let thickness = 16.0
  let d = seq.scale.domain
  let lo = d[0]
  let hi = d[d.length() - 1]
  let frac = @scale.Continuous::new(Linear)
  frac.domain = [lo, hi]
  let fraction = fn(v : Double) -> Double {
    match frac.map(v) {
      Some(x) => x
      None => @double.not_a_number
    }
  }
  // the colour ramp
  let stop_values = seq.scale.ticks(count=15.0)
  if lo != stop_values[0] {
    stop_values.insert(0, lo)
  }
  if hi != stop_values[stop_values.length() - 1] {
    stop_values.push(hi)
  }
  let stops : Array[@value.Value] = []
  for v in stop_values {
    stops.push(
      Obj(
        Map::from_array([
          ("offset", Num(fraction(v))),
          ("color", Str(seq.map(v).unwrap_or(""))),
        ]),
      ),
    )
  }
  let ramp = mk_item([
    ("x", num(0.0)),
    ("y", num(0.0)),
    ("width", num(thickness)),
    ("height", num(length)),
    ("stroke", str("#ddd")),
    ("strokeWidth", num(0.0)),
    (
      "fill",
      Obj(
        Map::from_array([
          ("gradient", Str("linear")),
          ("x1", Num(0.0)),
          ("y1", Num(1.0)),
          ("x2", Num(0.0)),
          ("y2", Num(0.0)),
          ("stops", Arr(stops)),
        ]),
      ),
    ),
  ])
  ramp.set_num("opacity", ramp_opacity)
  // labels at the ticks
  let count = max(2.0, 2.0 * (length / 100.0).floor())
  let mut values = seq.scale.ticks(count~)
  if values.length() < 3 && lo != hi {
    values = [lo, hi]
  }
  let fmt = @format.format_span(lo, hi, count, specifier?=label_format) catch {
    _ => raise CompileError("legend.format 无效")
  }
  let label_items = values.map(fn(v) {
    let perc = fraction(v)
    let it = text_item(
      [
        ("opacity", num(1.0)),
        ("text", str(fmt(v))),
        ("align", str("left")),
        (
          "baseline",
          str(
            if perc <= 0.0 {
              "bottom"
            } else if perc >= 1.0 {
              "top"
            } else {
              "middle"
            },
          ),
        ),
      ],
      "guide-label",
    )
    it.set_num("y", (1.0 - perc) * length)
    it.set_num("x", thickness + 2.0)
    it
  })
  let ramp_mark = @scene.Mark::new(
    Rect,
    role="legend-gradient",
    interactive=false,
    items=[ramp],
  )
  let label_mark = @scene.Mark::new(
    Text,
    role="legend-label",
    interactive=false,
    items=label_items,
  )
  let entry_group = mk_item([("x", num(0.0)), ("y", num(0.0))])
  entry_group.children.push(ramp_mark)
  entry_group.children.push(label_mark)
  let entry_mark = @scene.Mark::new(
    Group,
    role="legend-entry",
    interactive=false,
    items=[entry_group],
  )
  let item = mk_item([
    ("orient", str("right")),
    ("padding", num(0.0)),
    ("titlePadding", num(5.0)),
  ])
  item.children.push(entry_mark)
  let title_mark = match title {
    Some(t) => {
      let it = text_item(
        [
          ("opacity", num(1.0)),
          ("orient", str("top")),
          ("text", str(t)),
          ("limit", num(180.0)),
          ("x", num(0.0)),
          ("y", num(0.0)),
          ("anchor", str("start")),
          ("angle", num(0.0)),
          ("align", str("left")),
          ("baseline", str("top")),
        ],
        "guide-title",
      )
      let m = @scene.Mark::new(Text, role="legend-title", interactive=false, items=[
        it,
      ])
      item.children.push(m)
      Some(m)
    }
    None => None
  }
  let mark = @scene.Mark::new(Group, role="legend", interactive=false, items=[
    item,
  ])
  try {
    @scene.bound_mark(ramp_mark)
    @scene.bound_mark(label_mark)
    remove_overlap(label_mark, "parity", 0.0)
    ignore(entry_group.bounds.clear())
    ignore(@scene.bound_group(entry_group.bounds, entry_group))
    ignore(entry_mark.bounds.clear().union(entry_group.bounds))
    match title_mark {
      Some(m) => @scene.bound_mark(m)
      None => ()
    }
    ignore(item.bounds.clear())
    ignore(@scene.bound_group(item.bounds, item))
    ignore(mark.bounds.clear().union(item.bounds))
  } catch {
    @scene.SceneError(m) => raise CompileError(m)
  }
  {
    mark,
    orient: "right",
    entry_items: [],
    scope_mark: @scene.Mark::new(Group, role="scope"),
    entry_mark,
    title_mark,
  }
}
