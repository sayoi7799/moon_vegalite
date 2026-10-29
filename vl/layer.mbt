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
  /// whether its data is the top-level data with only top-level transforms
  /// before the layer's own ones (so that a bin can be shared by all layers)
  on_root_data : Bool
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
    let mut ancestor_transforms = 0
    let mut encoding : Array[(String, @spec.ChannelDef)] = []
    for i in 0..<chain.length() {
      if i >= owner {
        for t in chain[i].transform {
          transform.push(t)
        }
        if i < chain.length() - 1 {
          ancestor_transforms += chain[i].transform.length()
        }
      }
      encoding = merge_encoding(encoding, chain[i].encoding)
    }
    out.push({
      path,
      name,
      on_root_data: owner == 0 && ancestor_transforms == top.transform.length(),
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
/// Titles of the layers of a shared guide, merged pairwise as vega-lite's
/// `mergeTitleComponent` does: an explicit title (set on the channel) beats an
/// implicit one, otherwise a title is appended unless it repeats the previous
/// result or is empty (a datum has no title).
fn merge_titles_all(ps : Array[Pos]) -> String {
  let mut title = ""
  let mut explicit = false
  for i in 0..<ps.length() {
    let t = ps[i].title
    let e = ps[i].def.title is Some(Some(_))
    if i == 0 {
      title = t
      explicit = e
    } else if explicit != e {
      if e {
        title = t
        explicit = true
      }
    } else if t == title || t == "" {
      ()
    } else if title == "" {
      title = t
    } else {
      title = title + ", " + t
    }
  }
  title
}

///|
/// How a channel is resolved across layers: `resolve.<kind>.<channel>`, else shared.
fn resolve_mode(top : @spec.Spec, kind : String, channel : String) -> String {
  let m = match kind {
    "scale" => top.resolve.scale
    "axis" => top.resolve.axis
    _ => top.resolve.legend
  }
  match m.get(channel) {
    Some(v) => v
    None => "shared"
  }
}

///|
/// The kind of a position scale for merging: vega-lite merges scales of the
/// same category only (numeric / time / discrete position).
fn scale_category(p : Pos) -> String {
  if p.discrete {
    "discrete"
  } else if p.temporal {
    "time"
  } else {
    match p.def.scale {
      Some(m) =>
        match m.get("type") {
          Some(Str(t)) => "numeric:" + t
          _ => "numeric:linear"
        }
      None => "numeric:linear"
    }
  }
}

///|
/// Layers that bin the same field in the same way share one bin transform:
/// vega-lite's optimizer hoists it above the layers' own transforms, so the
/// bins come from the extent of the data they have in common.
fn shared_layer_bins(
  top : @spec.Spec,
  leaves : Array[Leaf],
) -> Map[String, @transform.BinParams] raise CompileError {
  let out : Map[String, @transform.BinParams] = Map([])
  for chan in ["x", "y"] {
    let binned : Array[(Leaf, String, Map[String, @value.Value])] = []
    for leaf in leaves {
      match find_channel(leaf.spec, chan) {
        Some({ field: Some(f), bin: Some(m), aggregate: None, .. }) =>
          binned.push((leaf, f, m))
        _ => ()
      }
    }
    if binned.length() < 2 {
      continue
    }
    let signature = fn(f : String, m : Map[String, @value.Value]) -> String {
      let keys : Array[String] = []
      for k, _ in m {
        keys.push(k)
      }
      keys.sort()
      f + "|" + keys.map(fn(k) { k + "=" + m[k].to_js_string() }).join(";")
    }
    let first = signature(binned[0].1, binned[0].2)
    for b in binned {
      if signature(b.1, b.2) != first || !b.0.on_root_data {
        raise nope(
          b.0.path +
          ".encoding." +
          chan +
          ".bin (多个 layer 的分箱不一致)",
        )
      }
    }
    let data = match top.data {
      Some(d) => d
      None => raise CompileError("data 缺失")
    }
    let rows = apply_transforms(data.map(fn(r) { r.copy() }), top.transform)
    out[chan] = bin_params(rows, binned[0].1, binned[0].2, 10.0)
  }
  out
}

///|
/// Compile a layered specification.
fn compile_layers(top : @spec.Spec) -> Compiled raise CompileError {
  validate_config(top.config)
  let leaves = flatten_layers(top)
  let shared_bins = shared_layer_bins(top, leaves)
  let units : Array[UnitModel] = []
  for leaf in leaves {
    try validate(leaf.spec) catch {
      CompileError(m) => raise CompileError(leaf.path + "." + m)
    } noraise {
      _ => ()
    }
    units.push(build_unit(leaf.spec, shared_bins~))
  }
  let n = units.length()
  let pos_of_unit = fn(i : Int32, chan : String) -> Pos {
    (if chan == "x" { units[i].px } else { units[i].py }).unwrap()
  }
  // --- position scales: shared by the layers that encode the channel, unless
  // the specification says otherwise or the scales cannot be merged
  let members_of = fn(chan : String) -> Array[Int32] {
    let members : Array[Int32] = []
    for i in 0..<n {
      let p = if chan == "x" { units[i].px } else { units[i].py }
      if p is Some(_) {
        members.push(i)
      }
    }
    members
  }
  let xm = members_of("x")
  let ym = members_of("y")
  let shared_pos = fn(chan : String, members : Array[Int32]) -> Bool {
    if members.length() < 2 {
      return true
    }
    let mode = resolve_mode(top, "scale", chan)
    let first = scale_category(pos_of_unit(members[0], chan))
    let compatible = members.all(fn(i) {
      scale_category(pos_of_unit(i, chan)) == first
    })
    mode != "independent" && compatible
  }
  let x_shared = shared_pos("x", xm)
  let y_shared = shared_pos("y", ym)
  // separate axes on a shared scale are not implemented
  for chan in ["x", "y"] {
    let shared = if chan == "x" { x_shared } else { y_shared }
    let members = if chan == "x" { xm } else { ym }
    if shared &&
      members.length() > 1 &&
      resolve_mode(top, "axis", chan) == "independent" {
      raise nope("resolve.axis." + chan + " independent (共用比例尺)")
    }
  }
  for chan in ["x", "y"] {
    let members = if chan == "x" { xm } else { ym }
    let shared = if chan == "x" { x_shared } else { y_shared }
    if !shared && members.any(fn(i) { pos_of_unit(i, chan).discrete }) {
      raise nope("resolve.scale." + chan + " independent (离散比例尺)")
    }
  }
  // the unit that gives a merged scale its style: a band scale wins
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
    shared : Bool,
  ) -> Double {
    let size = if chan == "x" { top.width } else { top.height }
    if members.length() == 0 {
      return axis_size(None, 0, "", step_of(size), 200.0, size)
    }
    let discrete = pos_of_unit(members[0], chan).discrete
    let si = style_unit(members)
    let count = if discrete && shared {
      sorted_unique_multi(srcs_of(members, chan)).length()
    } else {
      0
    }
    axis_size(
      Some(pos_of_unit(members[0], chan)),
      count,
      units[si].mark,
      step_of(size),
      200.0,
      size,
    )
  }
  let width = size_of(xm, "x", x_shared)
  let height = size_of(ym, "y", y_shared)
  // a binned layer leads a shared scale: its bins give the ticks and the style
  let is_binned = fn(i : Int32, chan : String) -> Bool {
    pos_of_unit(i, chan).def.bin is Some(_) && units[i].bin_info.contains(chan)
  }
  let lead_of = fn(members : Array[Int32], chan : String) -> Int32 {
    for i in members {
      if is_binned(i, chan) {
        return i
      }
    }
    members[0]
  }
  let make_scale = fn(
    members : Array[Int32],
    chan : String,
    r0 : Double,
    r1 : Double,
  ) -> (RScale, Array[@value.Value]) {
    let si = style_unit(members)
    let f = lead_of(members, chan)
    let u = units[f]
    let binned = members.filter(fn(i) { is_binned(i, chan) })
    let others = members.filter(fn(i) { !is_binned(i, chan) })
    let result = pos_scale(
      pos_of_unit(f, chan),
      srcs_of(if binned.length() > 0 { binned } else { members }, chan),
      units[si].mark,
      r0,
      r1,
      u.bin_info.get(chan),
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
    )
    // other layers sharing a binned scale widen its domain, which is then niced
    match result.0 {
      Binned(c, _) if others.length() > 0 =>
        match domain_extent_multi(srcs_of(others, chan), false) {
          Some((lo, hi)) => {
            c.domain = [min(c.domain[0], lo), max(c.domain[1], hi)]
            c.nice()
          }
          None => ()
        }
      _ => ()
    }
    result
  }
  // one scale per layer (layers of a shared channel point at the same one)
  let xs_per : Array[(RScale, Array[@value.Value])?] = Array::make(n, None)
  let ys_per : Array[(RScale, Array[@value.Value])?] = Array::make(n, None)
  for chan in ["x", "y"] {
    let members = if chan == "x" { xm } else { ym }
    let shared = if chan == "x" { x_shared } else { y_shared }
    let target = if chan == "x" { xs_per } else { ys_per }
    let range = fn(i : Int32) -> (Double, Double) {
      if chan == "x" {
        (0.0, width)
      } else if pos_of_unit(i, chan).discrete {
        (0.0, height)
      } else {
        (height, 0.0)
      }
    }
    if members.length() > 0 {
      if shared {
        let (r0, r1) = range(members[0])
        let sc = make_scale(members, chan, r0, r1)
        for i in members {
          target[i] = Some(sc)
        }
      } else {
        for i in members {
          let (r0, r1) = range(i)
          target[i] = Some(make_scale([i], chan, r0, r1))
        }
      }
    }
  }
  // --- non-positional scales: colours are shared by default, the other
  // channels are only supported when one layer uses them (or when independent)
  let color_users : Array[Int32] = []
  for i in 0..<n {
    if units[i].pcolor is Some(_) {
      color_users.push(i)
    }
  }
  for ch in ["size", "opacity", "shape"] {
    let users = units.filter(fn(u) {
      match ch {
        "size" => u.psize is Some(_)
        "opacity" => u.popacity is Some(_)
        _ => u.pshape is Some(_)
      }
    })
    // a size scale may be shared when each layer keeps its own legend
    let separate_legends = ch == "size" &&
      resolve_mode(top, "legend", ch) == "independent"
    if users.length() > 1 &&
      resolve_mode(top, "scale", ch) != "independent" &&
      !separate_legends {
      raise nope("encoding." + ch + " (多个 layer 使用同一通道)")
    }
  }
  // one size scale over the domains of all layers that encode size
  let size_users : Array[Int32] = []
  for i in 0..<n {
    if units[i].psize is Some(_) {
      size_users.push(i)
    }
  }
  let size_shared = size_users.length() > 1 &&
    resolve_mode(top, "scale", "size") != "independent"
  let merged_size : @scale.Continuous? = if size_shared {
    let s = units[size_users[0]]
    let base = unit_scales(s, width, height).size_scale.unwrap()
    match
      domain_extent_multi(
        size_users.map(fn(i) {
          (units[i].data, [units[i].psize.unwrap().field])
        }),
        true,
      ) {
      Some((lo, hi)) => base.domain = [lo, hi]
      None => ()
    }
    Some(base)
  } else {
    None
  }
  let color_shared = color_users.length() > 1 &&
    resolve_mode(top, "scale", "color") != "independent"
  if color_shared {
    for i in color_users {
      let c = units[i].pcolor.unwrap()
      if c.typ == "quantitative" {
        raise nope("encoding.color (多个 layer 共用连续颜色)")
      }
    }
    if resolve_mode(top, "legend", "color") == "independent" {
      raise nope("resolve.legend.color independent (共用颜色比例尺)")
    }
  }
  let merged_color = @scale.Ordinal::new()
  let merged_color_domain = if color_shared {
    sorted_unique_multi(
      color_users.map(fn(i) {
        (units[i].data, [units[i].pcolor.unwrap().field])
      }),
    )
  } else {
    []
  }
  set_color_range(
    merged_color,
    merged_color_domain,
    color_users.any(fn(i) { units[i].pcolor.unwrap().typ == "ordinal" }),
  )
  // --- marks and legends, one mark group per layer in layer order
  let marks : Array[@scene.Mark] = []
  let legends : Array[Legend] = []
  let scales : Array[UnitScales] = []
  for i in 0..<n {
    let u = units[i]
    let base = unit_scales(
      u,
      width,
      height,
      xs_shared?=xs_per[i],
      ys_shared?=ys_per[i],
    )
    let sc = if color_shared && u.pcolor is Some(_) {
      { ..base, color_scale: merged_color, color_domain: merged_color_domain, }
    } else {
      base
    }
    let sc = match merged_size {
      Some(ms) if u.psize is Some(_) => { ..sc, size_scale: Some(ms), }
      _ => sc
    }
    scales.push(sc)
    marks.push(unit_mark(u, sc, width, height, name=leaves[i].name + "_marks"))
    let first_color = color_shared && color_users[0] == i
    // the legend of a shared colour scale carries the titles of all its layers
    let u_legend = if first_color {
      let c = u.pcolor.unwrap()
      let joined = merge_titles_all(
        color_users.map(fn(k) { units[k].pcolor.unwrap() }),
      )
      { ..u, pcolor: Some({ ..c, title: joined, }), }
    } else {
      u
    }
    // layers sharing a colour scale give one legend: "circle" is preferred over
    // other symbol shapes and the first opacity found is kept
    let shape_hint : String? = if first_color {
      let mut shape = legend_symbol_shape(units[color_users[0]].mark)
      for k in color_users {
        let st = legend_symbol_shape(units[k].mark)
        if st == "circle" {
          shape = st
        }
      }
      Some(shape)
    } else {
      None
    }
    let opacity_hint : Double? = if first_color {
      let mut found : Double? = None
      for k in color_users {
        if found is None {
          found = mark_opacity(units[k].mark, units[k].spec)
        }
      }
      found
    } else {
      None
    }
    // a layer colouring by stroke and another by fill give a legend with both
    let channels : Array[String]? = if first_color {
      let chs : Array[String] = []
      for k in color_users {
        let ch = if is_filled_mark(units[k].mark, units[k].spec) {
          "fill"
        } else {
          "stroke"
        }
        if !chs.contains(ch) {
          chs.push(ch)
        }
      }
      Some(chs)
    } else {
      None
    }
    let made = unit_legends(
      u_legend,
      sc,
      height,
      skip_color=color_shared && !first_color,
      shape_override?=shape_hint,
      opacity_override?=opacity_hint,
      color_channels?=channels,
    )
    for l in made {
      legends.push(l)
    }
  }
  // --- axes: one per shared channel (titles joined), one per layer when the
  // scales are independent; the second axis of a channel goes to the other side
  let axes_grid : Array[Axis] = []
  let axes_main : Array[Axis] = []
  let count_orient : Map[String, Int32] = Map([])
  let pick_orient = fn(default : String, opposite : String) -> String {
    let c = count_orient.get(default).unwrap_or(0)
    let co = count_orient.get(opposite).unwrap_or(0)
    if c > 0 && c > co {
      opposite
    } else {
      default
    }
  }
  let first_x = if xm.length() > 0 { Some(xm[0]) } else { None }
  let first_y = if ym.length() > 0 { Some(ym[0]) } else { None }
  for chan in ["x", "y"] {
    let members = if chan == "x" { xm } else { ym }
    let shared = if chan == "x" { x_shared } else { y_shared }
    let owners = if shared && members.length() > 0 {
      [lead_of(members, chan)]
    } else {
      members
    }
    for k in 0..<owners.length() {
      let i = owners[k]
      let u = units[i]
      let p = pos_of_unit(i, chan)
      let titled = if shared {
        let joined = merge_titles_all(
          members.map(fn(m) { pos_of_unit(m, chan) }),
        )
        { ..p, title: joined, }
      } else {
        p
      }
      let default_orient = if chan == "x" { "bottom" } else { "left" }
      let orient = if chan == "x" {
        pick_orient("bottom", "top")
      } else {
        pick_orient("left", "right")
      }
      // vega-lite counts the default side even when the axis moved to the other
      count_orient[default_orient] = count_orient
        .get(default_orient)
        .unwrap_or(0) +
        1
      // grid lines span the first scale of the other channel
      let other_x = match first_x {
        Some(f) => units[f].px
        None => None
      }
      let other_y = match first_y {
        Some(f) => units[f].py
        None => None
      }
      let au : UnitModel = if chan == "x" {
        { ..u, px: Some(titled), py: other_y, }
      } else {
        { ..u, px: other_x, py: Some(titled), }
      }
      let sc = {
        ..scales[i],
        xs: match first_x {
          Some(f) => if chan == "x" { xs_per[i] } else { xs_per[f] }
          None => None
        },
        ys: match first_y {
          Some(f) => if chan == "y" { ys_per[i] } else { ys_per[f] }
          None => None
        },
      }
      let produced = unit_axes(
        au,
        sc,
        width,
        height,
        x_orient=if chan == "x" { orient } else { "bottom" },
        y_orient=if chan == "y" { orient } else { "left" },
        with_x=chan == "x",
        with_y=chan == "y",
        with_grid=k == 0,
      )
      for a in produced {
        if a.has_grid && !a.has_labels {
          axes_grid.push(a)
        } else {
          axes_main.push(a)
        }
      }
    }
  }
  let axes : Array[Axis] = []
  for a in axes_grid {
    axes.push(a)
  }
  for a in axes_main {
    axes.push(a)
  }
  let title = match top.title {
    Some(t) => Some(build_title(t))
    None => None
  }
  assemble(
    top,
    axes,
    marks,
    legends,
    title,
    width,
    height,
    framed=units.any(fn(u) { u.px is Some(_) || u.py is Some(_) }),
  )
}
