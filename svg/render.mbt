// Scenegraph to SVG text, following vega-scenegraph's SVGStringRenderer
// (BSD-3-Clause). Accessibility roles and labels (`role`, `aria-label`,
// `aria-roledescription`) are not emitted; `aria-hidden` is.

///|
fn inner_text(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
}

///|
fn attr_text(s : String) -> String {
  inner_text(s)
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="\t", new="&#x9;")
  .replace_all(old="\n", new="&#xA;")
  .replace_all(old="\r", new="&#xD;")
}

///|
/// An ordered list of attributes; entries whose value is None are skipped.
priv struct Attrs {
  items : Array[(String, String?)]
}

///|
fn Attrs::new() -> Attrs {
  { items: [], }
}

///|
fn Attrs::emit(self : Attrs, name : String, value : String?) -> Unit {
  // re-emitting a name keeps its original position (JavaScript object semantics)
  for i in 0..<self.items.length() {
    if self.items[i].0 == name {
      self.items[i] = (name, value)
      return
    }
  }
  self.items.push((name, value))
}

///|
/// d3-style incremental markup writer (vega-scenegraph `markup()`).
priv struct Markup {
  buf : StringBuilder
  mut outer : String
  mut inner : String
  stack : Array[String]
}

///|
fn Markup::new() -> Markup {
  { buf: StringBuilder(), outer: "", inner: "", stack: [], }
}

///|
fn Markup::clear(self : Markup) -> Unit {
  self.outer = ""
  self.inner = ""
}

///|
fn Markup::open(self : Markup, tag : String, attrs : Array[Attrs]) -> Unit {
  if self.outer != "" {
    self.buf.write_string(self.outer + ">" + self.inner)
    self.clear()
  }
  self.stack.push(tag)
  self.outer = "<" + tag
  for set in attrs {
    for pair in set.items {
      match pair.1 {
        Some(v) =>
          self.outer = self.outer + " " + pair.0 + "=\"" + attr_text(v) + "\""
        None => ()
      }
    }
  }
}

///|
fn Markup::close(self : Markup) -> Unit {
  let tag = self.stack.pop().unwrap_or("")
  if self.outer != "" {
    self.buf.write_string(
      self.outer +
      (if self.inner != "" {
        ">" + self.inner + "</" + tag + ">"
      } else {
        "/>"
      }),
    )
  } else {
    self.buf.write_string("</" + tag + ">")
  }
  self.clear()
}

///|
fn Markup::text(self : Markup, t : String) -> Unit {
  self.inner = self.inner + inner_text(t)
}

// ---- rendering ----

///|
/// Output options for `render_svg`.
pub struct SvgOptions {
  width : Double
  height : Double
  /// translation of the root group (the view origin)
  origin : (Double, Double)
  background : String?
  scale : Double
}

///|
pub fn SvgOptions::new(
  width : Double,
  height : Double,
  origin~ : (Double, Double) = (0.0, 0.0),
  background? : String,
  scale~ : Double = 1.0,
) -> SvgOptions {
  { width, height, origin, background, scale, }
}

///|
priv struct Defs {
  clips : Array[(String, @scene.Item)]
  mut next_clip : Int32
}

///|
fn js_num(x : Double) -> String {
  @util.js_number_to_string(x)
}

///|
fn translate(x : Double, y : Double) -> String {
  "translate(" + js_num(x) + "," + js_num(y) + ")"
}

///|
fn translate_item(item : @scene.Item) -> String {
  translate(item.num0("x"), item.num0("y"))
}

///|
fn rotate_item(item : @scene.Item) -> String {
  translate_item(item) +
  (if item.truthy("angle") {
    " rotate(" + @value.Value::to_js_string(item.get("angle")) + ")"
  } else {
    ""
  })
}

///|
fn css_class(mark : @scene.Mark) -> String {
  "mark-" +
  mark.marktype.name() +
  (match mark.role {
    Some(r) if r != "" => " role-" + r
    _ => ""
  }) +
  (match mark.name {
    Some(n) if n != "" => " " + n
    _ => ""
  })
}

///|
fn tag_of(t : @scene.MarkType) -> String {
  match t {
    Group => "g"
    Rect | Symbol | Line | Area => "path"
    Rule => "line"
    Text => "text"
  }
}

///|
/// Rectangle offset that keeps thin strokes crisp (vega `group.js` `offset`).
fn group_offset(item : @scene.Item) -> Double {
  let sw = item.num_or("strokeWidth", 1.0)
  match item.opt_num("strokeOffset") {
    Some(o) => o
    None =>
      if item.truthy("stroke") && sw > 0.5 && sw < 1.5 {
        0.5 - (sw - 1.0).abs()
      } else {
        0.0
      }
  }
}

///|
fn opt_str(v : @value.Value) -> String? {
  match v {
    Null | Undef => None
    other => Some(other.to_js_string())
  }
}

///|
/// vega's `style()` helper: presentation attributes of an item. `tag` is the
/// element being rendered; "bgrect" / "bgfore" are group background and
/// foreground paths.
fn style_attrs(
  attrs : Attrs,
  item : @scene.Item,
  interactive : Bool,
  tag : String,
) -> Unit {
  if tag == "bgrect" && !interactive {
    attrs.emit("pointer-events", Some("none"))
  }
  if tag == "bgfore" {
    if !interactive {
      attrs.emit("pointer-events", Some("none"))
    }
    attrs.emit("display", Some("none"))
    if !(item.get("fill") is Null) {
      return
    }
  }
  if tag == "text" {
    attrs.emit(
      "font-family",
      Some(
        match item.get("font") {
          v if v.truthy() => v.to_js_string()
          _ => "sans-serif"
        },
      ),
    )
    attrs.emit("font-size", Some(js_num(@scene.font_size(item)) + "px"))
    attrs.emit("font-style", opt_str(item.get("fontStyle")))
    attrs.emit("font-variant", opt_str(item.get("fontVariant")))
    attrs.emit("font-weight", opt_str(item.get("fontWeight")))
  }
  let table = [
    ("fill", "fill"),
    ("fillOpacity", "fill-opacity"),
    ("stroke", "stroke"),
    ("strokeOpacity", "stroke-opacity"),
    ("strokeWidth", "stroke-width"),
    ("strokeCap", "stroke-linecap"),
    ("strokeJoin", "stroke-linejoin"),
    ("strokeDash", "stroke-dasharray"),
    ("strokeDashOffset", "stroke-dashoffset"),
    ("strokeMiterLimit", "stroke-miterlimit"),
    ("opacity", "opacity"),
  ]
  for pair in table {
    let name = pair.1
    match item.get(pair.0) {
      Null | Undef => ()
      Str("transparent") if name == "fill" || name == "stroke" => ()
      v => attrs.emit(name, Some(v.to_js_string()))
    }
  }
  match item.get("blend") {
    Null | Undef => ()
    v => attrs.emit("style", Some("mix-blend-mode: " + v.to_js_string() + ";"))
  }
}

///|
fn item_aria(attrs : Attrs, item : @scene.Item) -> Unit {
  attrs.emit(
    "aria-hidden",
    if item.get("aria") is Bool(false) {
      Some("true")
    } else {
      None
    },
  )
}

///|
fn clip_ref(defs : Defs, item : @scene.Item) -> String {
  let id = "clip" + defs.next_clip.to_string()
  defs.next_clip = defs.next_clip + 1
  defs.clips.push((id, item))
  "url(#" + id + ")"
}

///|
fn render_mark(
  m : Markup,
  mark : @scene.Mark,
  parent : @scene.Item?,
  defs : Defs,
) -> Unit raise @scene.SceneError {
  let tag = tag_of(mark.marktype)
  let g_attrs = Attrs::new()
  g_attrs.emit("class", Some(css_class(mark)))
  g_attrs.emit(
    "clip-path",
    if mark.clip {
      match parent {
        Some(p) => Some(clip_ref(defs, p))
        None => None
      }
    } else {
      None
    },
  )
  let aria_attrs = Attrs::new()
  if !mark.aria {
    aria_attrs.emit("aria-hidden", Some("true"))
  }
  let pe = Attrs::new()
  pe.emit(
    "pointer-events",
    if tag != "g" && !mark.interactive {
      Some("none")
    } else {
      None
    },
  )
  m.open("g", [g_attrs, aria_attrs, pe])
  if mark.marktype.is_nested() {
    if mark.items.length() > 0 {
      let item = mark.items[0]
      let a = Attrs::new()
      item_aria(a, item)
      let d = if mark.marktype is Line {
        @scene.line_path(mark.items)
      } else {
        @scene.area_path(mark.items)
      }
      a.emit("d", if d == "" { None } else { Some(d) })
      style_attrs(a, item, mark.interactive, tag)
      m.open(tag, [a])
      m.close()
    }
  } else {
    for item in mark.items {
      render_item(m, mark, item, tag, defs)
    }
  }
  m.close()
}

///|
fn render_item(
  m : Markup,
  mark : @scene.Mark,
  item : @scene.Item,
  tag : String,
  defs : Defs,
) -> Unit raise @scene.SceneError {
  let a = Attrs::new()
  item_aria(a, item)
  match mark.marktype {
    Group => a.emit("transform", Some(translate_item(item)))
    Rect => a.emit("d", Some(@scene.rect_path(item)))
    Rule => {
      a.emit("transform", Some(translate_item(item)))
      a.emit(
        "x2",
        Some(
          match item.opt_num("x2") {
            Some(v) => js_num(v - item.num0("x"))
            None => "0"
          },
        ),
      )
      a.emit(
        "y2",
        Some(
          match item.opt_num("y2") {
            Some(v) => js_num(v - item.num0("y"))
            None => "0"
          },
        ),
      )
    }
    Text => {
      let anchor = match item.str("align") {
        Some("center") => "middle"
        Some("right") => "end"
        _ => "start"
      }
      a.emit("text-anchor", Some(anchor))
      let dx = item.num0("dx")
      let dy = item.num0("dy") + @scene.baseline_offset(item)
      let x = item.num0("x")
      let y = item.num0("y")
      let angle = item.num0("angle")
      a.emit(
        "transform",
        Some(
          if angle != 0.0 {
            translate(x, y) +
            " rotate(" +
            js_num(angle) +
            ")" +
            (if dx != 0.0 || dy != 0.0 { " " + translate(dx, dy) } else { "" })
          } else {
            translate(x + dx, y + dy)
          },
        ),
      )
    }
    Symbol => {
      a.emit("transform", Some(rotate_item(item)))
      let d = @scene.symbol_path(item)
      a.emit("d", if d == "" { None } else { Some(d) })
    }
    _ => ()
  }
  if tag != "g" {
    style_attrs(a, item, mark.interactive, tag)
  }
  m.open(tag, [a])
  match mark.marktype {
    Text =>
      match @scene.text_lines(item) {
        Lines(lines) =>
          for i in 0..<lines.length() {
            let ts = Attrs::new()
            if i > 0 {
              ts.emit("x", Some("0"))
              ts.emit("dy", Some(js_num(@scene.line_height(item))))
            }
            m.open("tspan", [ts])
            m.text(@scene.text_value(item, lines[i]))
            m.close()
          }
        Single(v) => m.text(@scene.text_value(item, v))
      }
    Group => render_group_content(m, mark, item, defs)
    _ => ()
  }
  m.close()
}

///|
fn render_group_content(
  m : Markup,
  mark : @scene.Mark,
  item : @scene.Item,
  defs : Defs,
) -> Unit raise @scene.SceneError {
  let off = group_offset(item)
  let fore = item.truthy("strokeForeground")
  let stroke = item.get("stroke")
  let has_fore_stroke = fore && stroke.truthy()
  // background (without the stroke when it is drawn in the foreground)
  let bg = Attrs::new()
  bg.emit("class", Some("background"))
  bg.emit("aria-hidden", Some("true"))
  bg.emit("d", Some(@scene.rect_path(item, x=off, y=off)))
  let bg_item = if has_fore_stroke {
    with_prop(item, "stroke", Null)
  } else {
    item
  }
  style_attrs(bg, bg_item, mark.interactive, "bgrect")
  m.open("path", [bg])
  m.close()
  // content
  let content = Attrs::new()
  if item.truthy("clip") {
    content.emit("clip-path", Some(clip_ref(defs, item)))
  }
  m.open("g", [content])
  for child in ordered_marks(item) {
    render_mark(m, child, Some(item), defs)
  }
  m.close()
  // foreground
  let fg = Attrs::new()
  fg.emit("class", Some("foreground"))
  fg.emit("aria-hidden", Some("true"))
  if fore {
    fg.emit("d", Some(@scene.rect_path(item, x=off, y=off)))
  } else {
    fg.emit("d", Some(""))
  }
  if has_fore_stroke {
    let fi = if item.truthy("fill") {
      with_prop(item, "fill", Null)
    } else {
      item
    }
    style_attrs(fg, fi, mark.interactive, "bgrect")
  } else {
    style_attrs(fg, item, mark.interactive, "bgfore")
  }
  m.open("path", [fg])
  m.close()
}

///|
/// A copy of the item with one property replaced.
fn with_prop(item : @scene.Item, key : String, v : @value.Value) -> @scene.Item {
  let props : Map[String, @value.Value] = Map([])
  for k, x in item.props {
    props[k] = x
  }
  props[key] = v
  @scene.Item::new(props~)
}

///|
fn ordered_marks(item : @scene.Item) -> Array[@scene.Mark] {
  let plain : Array[@scene.Mark] = []
  let z : Array[(Int32, Int32, @scene.Mark)] = []
  for i in 0..<item.children.length() {
    let c = item.children[i]
    match c.zindex {
      Some(zi) if zi != 0 => z.push((zi, i, c))
      _ => plain.push(c)
    }
  }
  if z.length() == 0 {
    return plain
  }
  // stable insertion sort by zindex
  let sorted : Array[(Int32, Int32, @scene.Mark)] = []
  for e in z {
    let mut pos = sorted.length()
    while pos > 0 && sorted[pos - 1].0 > e.0 {
      pos = pos - 1
    }
    sorted.insert(pos, e)
  }
  for e in sorted {
    plain.push(e.2)
  }
  plain
}

///|
/// Render a scenegraph to an SVG document string.
pub fn render_svg(
  scene : @scene.Mark,
  opts : SvgOptions,
) -> String raise @scene.SceneError {
  let m = Markup::new()
  let defs : Defs = { clips: [], next_clip: 1, }
  let root = Attrs::new()
  root.emit("xmlns", Some("http://www.w3.org/2000/svg"))
  root.emit("xmlns:xlink", Some("http://www.w3.org/1999/xlink"))
  root.emit("version", Some("1.1"))
  let sized = Attrs::new()
  sized.emit("class", Some("marks"))
  sized.emit("width", Some(js_num(opts.width * opts.scale)))
  sized.emit("height", Some(js_num(opts.height * opts.scale)))
  sized.emit(
    "viewBox",
    Some("0 0 " + js_num(opts.width) + " " + js_num(opts.height)),
  )
  m.open("svg", [root, sized])
  match opts.background {
    Some(bg) if bg != "transparent" && bg != "none" && bg != "" => {
      let r = Attrs::new()
      r.emit("width", Some(js_num(opts.width)))
      r.emit("height", Some(js_num(opts.height)))
      r.emit("fill", Some(bg))
      m.open("rect", [r])
      m.close()
    }
    _ => ()
  }
  let g1 = Attrs::new()
  g1.emit("fill", Some("none"))
  g1.emit("stroke-miterlimit", Some("10"))
  let g2 = Attrs::new()
  g2.emit(
    "transform",
    Some(
      "translate(" + js_num(opts.origin.0) + "," + js_num(opts.origin.1) + ")",
    ),
  )
  m.open("g", [g1, g2])
  render_mark(m, scene, None, defs)
  m.close()
  if defs.clips.length() > 0 {
    m.open("defs", [])
    for c in defs.clips {
      let ca = Attrs::new()
      ca.emit("id", Some(c.0))
      m.open("clipPath", [ca])
      if c.1.has_corner_radius() {
        let pa = Attrs::new()
        pa.emit("d", Some(@scene.rect_path(c.1, x=0.0, y=0.0)))
        m.open("path", [pa])
        m.close()
      } else {
        let ra = Attrs::new()
        ra.emit("x", Some("0"))
        ra.emit("y", Some("0"))
        ra.emit("width", Some(js_num(c.1.num0("width"))))
        ra.emit("height", Some(js_num(c.1.num0("height"))))
        m.open("rect", [ra])
        m.close()
      }
      m.close()
    }
    m.close()
  }
  m.close()
  m.buf.to_string()
}
