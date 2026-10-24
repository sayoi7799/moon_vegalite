// Chart titles: vega-parser `title.js` for a plain text title and the title
// layout of vega-view-transforms.

///|
pub struct Title {
  mark : @scene.Mark
}

///|
pub fn build_title(text : String) -> Title raise CompileError {
  let t = text_item(
    [
      ("opacity", num(1.0)),
      ("text", str(text)),
      ("baseline", str("top")),
      ("align", str("center")),
      ("angle", num(0.0)),
    ],
    "group-title",
  )
  let text_mark = @scene.Mark::new(Text, role="title-text", interactive=false, items=[
    t,
  ])
  let group = mk_item([
    ("orient", str("top")),
    ("anchor", str("middle")),
    ("frame", str("group")),
    ("offset", num(4.0)),
    ("padding", num(3.0)),
    ("align", str("center")),
    ("angle", num(0.0)),
  ])
  group.children.push(text_mark)
  let mark = @scene.Mark::new(Group, role="title", interactive=false, items=[
    group,
  ])
  @scene.bound_mark(mark) catch {
    @scene.SceneError(m) => raise CompileError(m)
  }
  { mark, }
}

///|
/// vega `titleLayout` for a top title framed by the group: centre it over the
/// plot and place it above the view bounds. Returns the title's bounds.
fn title_layout(
  t : Title,
  width : Double,
  view_bounds : @scene.Bounds,
) -> @scene.Bounds {
  let group = t.mark.items[0]
  let title = group.children[0].items[0]
  let offset = group.num0("offset")
  let pos = (0.0 + width) / 2.0
  let temp = title.bounds.copy()
  let x = pos
  let y = view_bounds.y1 - temp.height() - offset
  ignore(temp.translate(x, y))
  group.set_num("x", x)
  group.set_num("y", y)
  ignore(group.bounds.clear().union(temp))
  ignore(t.mark.bounds.clear().union(temp))
  group.bounds
}
