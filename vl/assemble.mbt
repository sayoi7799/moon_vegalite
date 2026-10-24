///|
/// Build the root group, run bounds and layout, and size the view.
fn assemble(
  spec : @spec.Spec,
  axes : Array[Axis],
  marks : Array[@scene.Mark],
  legends : Array[Legend],
  title : Title?,
  width : Double,
  height : Double,
) -> Compiled raise CompileError {
  let root = mk_item([
    ("fill", str("transparent")),
    ("stroke", str("#ddd")),
    ("x", num(0.0)),
    ("y", num(0.0)),
    ("width", num(width)),
    ("height", num(height)),
  ])
  try {
    for m in marks {
      @scene.bound_mark(m)
    }
  } catch {
    @scene.SceneError(m) => raise CompileError(m)
  }
  for a in axes {
    bound_axis(a)
  }
  let view = @scene.Bounds::new()
  ignore(view.set(0.0, 0.0, width, height))
  let xb = view.copy()
  let yb = view.copy()
  for a in axes {
    let b = axis_layout(a, width, height)
    if a.orient == "left" || a.orient == "right" {
      ignore(xb.union(b))
    } else {
      ignore(yb.union(b))
    }
  }
  for m in marks {
    ignore(view.union(m.bounds))
  }
  // legends: lay out each, then place them by orient next to the plot
  for l in legends {
    legend_layout(l)
  }
  for orient in ["left", "right", "top", "bottom"] {
    let group = legends.filter(fn(l) { l.orient == orient })
    if group.length() > 0 {
      place_legends(group, orient, xb, yb, 0.0, 0.0)
    }
  }
  for l in legends {
    ignore(view.union(legend_item(l).bounds))
  }
  ignore(view.union(xb).union(yb))
  match title {
    Some(t) => ignore(view.union(title_layout(t, width, view)))
    None => ()
  }
  for a in axes {
    root.children.push(a.mark)
  }
  for m in marks {
    root.children.push(m)
  }
  for l in legends {
    root.children.push(l.mark)
  }
  match title {
    Some(t) => root.children.push(t.mark)
    None => ()
  }
  ignore(@scene.bound_group(root.bounds.clear(), root))
  let left = max(0.0, ceil(-view.x1))
  let top = max(0.0, ceil(-view.y1))
  let right = max(0.0, ceil(view.x2 - width))
  let bottom = max(0.0, ceil(view.y2 - height))
  let frame = @scene.Mark::new(Group, name="root", role="frame", items=[root])
  ignore(frame.bounds.union(root.bounds))
  let pad = match spec.padding {
    Some(p) => p.to_number()
    None => 5.0
  }
  {
    scene: frame,
    width,
    height,
    origin: (left, top),
    padding: pad,
    view_width: width + left + right,
    view_height: height + top + bottom,
    background: match spec.background {
      Some(b) => Some(b)
      None => Some("white")
    },
  }
}
