// Layered views (`layer`): the layers are flattened into unit specifications
// that inherit the encoding, data and transforms of their parents, the scales
// of the position channels are shared between them, and their marks are drawn
// one on top of the other inside one plot with one set of axes.

///|
priv struct Leaf {
  /// JSON path of the layer ("layer[1]", "layer[0].layer[2]")
  path : String
  /// the name vega-lite gives its marks ("layer_1", "layer_0_layer_2")
  name : String
  /// the unit specification with everything inherited filled in
  spec : @spec.Spec
}

///|
fn[T] or_else(inner : T?, outer : T?) -> T? {
  match inner {
    Some(_) => inner
    None => outer
  }
}

///|
/// A channel definition of a layer on top of the one it inherits: every property
/// the layer sets wins, the others are kept (so `y: {field: "b"}` inside a layer
/// of `y: {aggregate: "mean", field: "a"}` means the mean of `b`). A constant
/// `value` replaces the inherited definition altogether.
fn merge_def(
  outer : @spec.ChannelDef,
  inner : @spec.ChannelDef,
) -> @spec.ChannelDef {
  if inner.value is Some(_) || inner.datum is Some(_) {
    return inner
  }
  {
    field: or_else(inner.field, outer.field),
    typ: or_else(inner.typ, outer.typ),
    aggregate: or_else(inner.aggregate, outer.aggregate),
    bin: or_else(inner.bin, outer.bin),
    binned: inner.binned || outer.binned,
    time_unit: or_else(inner.time_unit, outer.time_unit),
    sort: or_else(inner.sort, outer.sort),
    scale: or_else(inner.scale, outer.scale),
    scale_off: inner.scale_off || outer.scale_off,
    axis: match inner.axis {
      Default => outer.axis
      other => other
    },
    legend: match inner.legend {
      Default => outer.legend
      other => other
    },
    title: or_else(inner.title, outer.title),
    format: or_else(inner.format, outer.format),
    format_type: or_else(inner.format_type, outer.format_type),
    value: outer.value,
    datum: outer.datum,
    stack: or_else(inner.stack, outer.stack),
    band: or_else(inner.band, outer.band),
    band_position: or_else(inner.band_position, outer.band_position),
  }
}

///|
/// Merge `encoding` definitions channel by channel (see `merge_def`).
fn merge_encoding(
  outer : Array[(String, @spec.ChannelDef)],
  inner : Array[(String, @spec.ChannelDef)],
) -> Array[(String, @spec.ChannelDef)] {
  let out = outer.copy()
  for e in inner {
    let mut replaced = false
    for i in 0..<out.length() {
      if out[i].0 == e.0 {
        out[i] = (e.0, merge_def(out[i].1, e.1))
        replaced = true
      }
    }
    if !replaced {
      out.push(e)
    }
  }
  out
}

///|
/// The unit specifications below `top`, each with the data, transforms and
/// encoding it inherits. A layer with its own `data` starts from that data and
/// does not see the transforms above it.
fn flatten_layers(top : @spec.Spec) -> Array[Leaf] raise CompileError {
  let out : Array[Leaf] = []
  fn walk(
    node : @spec.Spec,
    path : String,
    name : String,
    chain : Array[@spec.Spec],
  ) -> Unit raise CompileError {
    if path != "" {
      if node.width is Some(_) {
        raise nope(@spec.join_path(path, "width"))
      }
      if node.height is Some(_) {
        raise nope(@spec.join_path(path, "height"))
      }
      if !node.resolve.scale.is_empty() ||
        !node.resolve.axis.is_empty() ||
        !node.resolve.legend.is_empty() {
        raise nope(@spec.join_path(path, "resolve"))
      }
    }
    if node.layer.length() > 0 {
      for i in 0..<node.layer.length() {
        let child = node.layer[i]
        let child_chain = chain.copy()
        child_chain.push(child)
        walk(
          child,
          @spec.index_path(@spec.join_path(path, "layer"), i),
          if name == "" {
            "layer_" + i.to_string()
          } else {
            name + "_layer_" + i.to_string()
          },
          child_chain,
        )
      }
      return
    }
    // the closest node with data supplies it, together with its transforms
    let mut owner = -1
    for i in 0..<chain.length() {
      if chain[i].data is Some(_) {
        owner = i
      }
    }
    if owner < 0 {
      raise CompileError("data 缺失")
    }
    let transform : Array[@spec.Transform] = []
    let mut encoding : Array[(String, @spec.ChannelDef)] = []
    for i in 0..<chain.length() {
      if i >= owner {
        for t in chain[i].transform {
          transform.push(t)
        }
      }
      encoding = merge_encoding(encoding, chain[i].encoding)
    }
    out.push({
      path,
      name,
      spec: {
        layer: [],
        resolve: top.resolve,
        mark: node.mark,
        encoding,
        transform,
        data: chain[owner].data,
        width: top.width,
        height: top.height,
        padding: top.padding,
        background: top.background,
        title: top.title,
        description: None,
        config: Map([]),
      },
    })
  }

  walk(top, "", "", [top])
  out
}

///|
/// Whether a position scale is band-like (bar, rect, tick, rule on a discrete
/// field) - such a scale wins when band and point scales are merged.
fn is_band_mark(mark : String) -> Bool {
  mark == "bar" || mark == "rect" || mark == "tick" || mark == "rule"
}

///|
fn merge_titles_all(titles : Array[String]) -> String {
  let uniq : Array[String] = []
  for t in titles {
    if !uniq.contains(t) {
      uniq.push(t)
    }
  }
  uniq.join(", ")
}

///|
/// Compile a layered specification.
fn compile_layers(top : @spec.Spec) -> Compiled raise CompileError {
  validate_config(top.config)
  let leaves = flatten_layers(top)
  let units : Array[UnitModel] = []
  for leaf in leaves {
    try validate(leaf.spec) catch {
      CompileError(m) => raise CompileError(leaf.path + "." + m)
    } noraise {
      _ => ()
    }
    units.push(build_unit(leaf.spec))
  }
  // a non-positional channel (colour, size, ...) may be encoded by one layer
  // only: sharing its scale between layers needs a merged domain and legend
  for ch in ["color", "size", "opacity", "shape"] {
    let users = units.filter(fn(u) {
      match ch {
        "color" => u.pcolor is Some(_)
        "size" => u.psize is Some(_)
        "opacity" => u.popacity is Some(_)
        _ => u.pshape is Some(_)
      }
    })
    if users.length() > 1 {
      raise nope("encoding." + ch + " (多个 layer 使用同一通道)")
    }
  }
  let config_zero = units[0].config_zero
  ignore(config_zero)
  // position scales shared by the layers that encode the channel
  let merge = fn(chan : String) -> (Array[Int32], Bool) raise CompileError {
    let members : Array[Int32] = []
    for i in 0..<units.length() {
      let p = if chan == "x" { units[i].px } else { units[i].py }
      if p is Some(_) {
        members.push(i)
      }
    }
    match top.resolve.scale.get(chan) {
      Some("independent") =>
        raise nope("resolve.scale." + chan + " independent")
      _ => ()
    }
    let mut discrete = false
    let mut continuous = false
    let mut temporal = false
    for i in members {
      let p = (if chan == "x" { units[i].px } else { units[i].py }).unwrap()
      if p.def.bin is Some(_) {
        raise nope("layer 中的 " + chan + " bin")
      }
      if p.discrete {
        discrete = true
      } else if p.temporal {
        temporal = true
      } else {
        continuous = true
      }
    }
    let kinds = (if discrete { 1 } else { 0 }) +
      (if temporal { 1 } else { 0 }) +
      (if continuous { 1 } else { 0 })
    if kinds > 1 {
      raise nope(
        "layer 间 " + chan + " 比例尺类型不兼容 (需要 independent)",
      )
    }
    if continuous {
      let types : Array[String] = []
      for i in members {
        let p = (if chan == "x" { units[i].px } else { units[i].py }).unwrap()
        let t = match p.def.scale {
          Some(m) =>
            match m.get("type") {
              Some(Str(t)) => t
              _ => "linear"
            }
          None => "linear"
        }
        if !types.contains(t) {
          types.push(t)
        }
      }
      if types.length() > 1 {
        raise nope("layer 间 " + chan + " 比例尺类型不同")
      }
    }
    (members, discrete)
  }
  let (xm, x_discrete) = merge("x")
  let (ym, y_discrete) = merge("y")
  let pos_of_unit = fn(i : Int32, chan : String) -> Pos {
    (if chan == "x" { units[i].px } else { units[i].py }).unwrap()
  }
  // the unit that gives the merged scale its style: a band scale wins
  let style_unit = fn(members : Array[Int32]) -> Int32 {
    for i in members {
      if is_band_mark(units[i].mark) {
        return i
      }
    }
    members[0]
  }
  let srcs_of = fn(members : Array[Int32], chan : String) {
    members.map(fn(i) {
      (
        units[i].data,
        if chan == "x" {
          units[i].xfields
        } else {
          units[i].yfields
        },
      )
    })
  }
  let order_of = fn(
    members : Array[Int32],
    chan : String,
  ) -> Array[@value.Value]? {
    for i in members {
      let o = if chan == "x" { units[i].x_order } else { units[i].y_order }
      if o is Some(_) {
        return o
      }
    }
    None
  }
  let size_of = fn(
    members : Array[Int32],
    chan : String,
    discrete : Bool,
  ) -> Double {
    let size = if chan == "x" { top.width } else { top.height }
    if members.length() == 0 {
      return axis_size(None, 0, "", step_of(size), 200.0, size)
    }
    let si = style_unit(members)
    let n = if discrete {
      sorted_unique_multi(srcs_of(members, chan)).length()
    } else {
      0
    }
    axis_size(
      Some(pos_of_unit(members[0], chan)),
      n,
      units[si].mark,
      step_of(size),
      200.0,
      size,
    )
  }
  let width = size_of(xm, "x", x_discrete)
  let height = size_of(ym, "y", y_discrete)
  let make_scale = fn(
    members : Array[Int32],
    chan : String,
    r0 : Double,
    r1 : Double,
  ) {
    if members.length() == 0 {
      return None
    }
    let si = style_unit(members)
    let f = members[0]
    let u = units[f]
    Some(
      pos_scale(
        pos_of_unit(f, chan),
        srcs_of(members, chan),
        units[si].mark,
        r0,
        r1,
        None,
        zero_of_chan(
          u.mark,
          u.orient,
          chan,
          if chan == "x" {
            u.px2 is Some(_)
          } else {
            u.py2 is Some(_)
          },
          u.config_zero,
        ),
        order_of(members, chan),
      ),
    )
  }
  let xs_m = make_scale(xm, "x", 0.0, width)
  let ys_m = if y_discrete {
    make_scale(ym, "y", 0.0, height)
  } else {
    make_scale(ym, "y", height, 0.0)
  }
  // marks, one mark group per layer in layer order
  let marks : Array[@scene.Mark] = []
  let legends : Array[Legend] = []
  let scales : Array[UnitScales] = []
  for i in 0..<units.length() {
    let u = units[i]
    let sc = unit_scales(
      u,
      width,
      height,
      xs_shared?=if u.px is Some(_) { xs_m } else { None },
      ys_shared?=if u.py is Some(_) { ys_m } else { None },
    )
    scales.push(sc)
    marks.push(unit_mark(u, sc, width, height, name=leaves[i].name + "_marks"))
    for l in unit_legends(u, sc, height) {
      legends.push(l)
    }
  }
  // one set of axes; titles of layers that share a channel are joined
  let ix = if xm.length() > 0 { xm[0] } else { 0 }
  let iy = if ym.length() > 0 { ym[0] } else { 0 }
  let px = match xm.length() {
    0 => None
    _ => {
      let p = pos_of_unit(ix, "x")
      Some({
        ..p,
        title: merge_titles_all(xm.map(fn(i) { pos_of_unit(i, "x").title })),
      })
    }
  }
  let py = match ym.length() {
    0 => None
    _ => {
      let p = pos_of_unit(iy, "y")
      Some({
        ..p,
        title: merge_titles_all(ym.map(fn(i) { pos_of_unit(i, "y").title })),
      })
    }
  }
  let ay = units[iy]
  let ax = units[ix]
  let au : UnitModel = {
    ..ax,
    px,
    py,
    stack_chan: if ay.stack_chan == Some("y") {
      ay.stack_chan
    } else {
      ax.stack_chan
    },
    stack_offset: if ay.stack_chan == Some("y") {
      ay.stack_offset
    } else {
      ax.stack_offset
    },
  }
  let axes = unit_axes(au, { ..scales[ix], xs: xs_m, ys: ys_m, }, width, height)
  let title = match top.title {
    Some(t) => Some(build_title(t))
    None => None
  }
  assemble(top, axes, marks, legends, title, width, height)
}
