// Shape generators for rect, symbol, line and area marks (vega-scenegraph
// path/shapes.js, path/symbols.js, path/rectangle.js and d3-shape).

///|
let half_sqrt3 : Double = 0.8660254037844386

///|
let tan30 : Double = 0.5773502691896257

///|
pub(all) suberror SceneError {
  SceneError(String)
}

///|
fn clamp(value : Double, lo : Double, hi : Double) -> Double {
  @util.js_max(lo, @util.js_min(value, hi))
}

///|
fn corner(item : Item, key : String) -> Double {
  match item.opt_num(key) {
    Some(v) => if v != 0.0 && !v.is_nan() { v } else { 0.0 }
    None => item.num0("cornerRadius")
  }
}

///|
pub fn Item::has_corner_radius(self : Item) -> Bool {
  self.truthy("cornerRadius") ||
  self.truthy("cornerRadiusTopLeft") ||
  self.truthy("cornerRadiusTopRight") ||
  self.truthy("cornerRadiusBottomRight") ||
  self.truthy("cornerRadiusBottomLeft")
}

///|
/// vega's `rectangle` shape: a plain rectangle or one with rounded corners.
pub fn draw_rect(ctx : Ctx, item : Item, x0? : Double, y0? : Double) -> Unit {
  let x1 = match x0 {
    Some(v) => v
    None => item.num0("x")
  }
  let y1 = match y0 {
    Some(v) => v
    None => item.num0("y")
  }
  let w = item.num0("width")
  let h = item.num0("height")
  let s = @util.js_min(w, h) / 2.0
  let tl = clamp(corner(item, "cornerRadiusTopLeft"), 0.0, s)
  let tr = clamp(corner(item, "cornerRadiusTopRight"), 0.0, s)
  let br = clamp(corner(item, "cornerRadiusBottomRight"), 0.0, s)
  let bl = clamp(corner(item, "cornerRadiusBottomLeft"), 0.0, s)
  if tl <= 0.0 && tr <= 0.0 && bl <= 0.0 && br <= 0.0 {
    ctx.rect(x1, y1, w, h)
  } else {
    let c = 0.448084975506
    let x2 = x1 + w
    let y2 = y1 + h
    ctx.move_to(x1 + tl, y1)
    ctx.line_to(x2 - tr, y1)
    ctx.bezier_to(x2 - c * tr, y1, x2, y1 + c * tr, x2, y1 + tr)
    ctx.line_to(x2, y2 - br)
    ctx.bezier_to(x2, y2 - c * br, x2 - c * br, y2, x2 - br, y2)
    ctx.line_to(x1 + bl, y2)
    ctx.bezier_to(x1 + c * bl, y2, x1, y2 - c * bl, x1, y2 - bl)
    ctx.line_to(x1, y1 + tl)
    ctx.bezier_to(x1, y1 + c * tl, x1 + c * tl, y1, x1 + tl, y1)
    ctx.close_path()
  }
}

///|
/// The symbol shapes of vega-scenegraph (`path/symbols.js`), drawn at the origin.
pub fn draw_symbol(
  ctx : Ctx,
  shape : String,
  size : Double,
) -> Unit raise SceneError {
  match shape {
    "circle" => {
      let r = size.sqrt() / 2.0
      ctx.move_to(r, 0.0)
      ctx.arc(0.0, 0.0, r, 0.0, tau, false)
    }
    "cross" => {
      let r = size.sqrt() / 2.0
      let s = r / 2.5
      ctx.move_to(-r, -s)
      ctx.line_to(-r, s)
      ctx.line_to(-s, s)
      ctx.line_to(-s, r)
      ctx.line_to(s, r)
      ctx.line_to(s, s)
      ctx.line_to(r, s)
      ctx.line_to(r, -s)
      ctx.line_to(s, -s)
      ctx.line_to(s, -r)
      ctx.line_to(-s, -r)
      ctx.line_to(-s, -s)
      ctx.close_path()
    }
    "diamond" => {
      let r = size.sqrt() / 2.0
      ctx.move_to(-r, 0.0)
      ctx.line_to(0.0, -r)
      ctx.line_to(r, 0.0)
      ctx.line_to(0.0, r)
      ctx.close_path()
    }
    "square" => {
      let w = size.sqrt()
      let x = -w / 2.0
      ctx.rect(x, x, w, w)
    }
    "arrow" => {
      let r = size.sqrt() / 2.0
      let s = r / 7.0
      let t = r / 2.5
      let v = r / 8.0
      ctx.move_to(-s, r)
      ctx.line_to(s, r)
      ctx.line_to(s, -v)
      ctx.line_to(t, -v)
      ctx.line_to(0.0, -r)
      ctx.line_to(-t, -v)
      ctx.line_to(-s, -v)
      ctx.close_path()
    }
    "wedge" => {
      let r = size.sqrt() / 2.0
      let h = half_sqrt3 * r
      let o = h - r * tan30
      let b = r / 4.0
      ctx.move_to(0.0, -h - o)
      ctx.line_to(-b, h - o)
      ctx.line_to(b, h - o)
      ctx.close_path()
    }
    "triangle" => {
      let r = size.sqrt() / 2.0
      let h = half_sqrt3 * r
      let o = h - r * tan30
      ctx.move_to(0.0, -h - o)
      ctx.line_to(-r, h - o)
      ctx.line_to(r, h - o)
      ctx.close_path()
    }
    "triangle-up" => {
      let r = size.sqrt() / 2.0
      let h = half_sqrt3 * r
      ctx.move_to(0.0, -h)
      ctx.line_to(-r, h)
      ctx.line_to(r, h)
      ctx.close_path()
    }
    "triangle-down" => {
      let r = size.sqrt() / 2.0
      let h = half_sqrt3 * r
      ctx.move_to(0.0, h)
      ctx.line_to(-r, -h)
      ctx.line_to(r, -h)
      ctx.close_path()
    }
    "triangle-right" => {
      let r = size.sqrt() / 2.0
      let h = half_sqrt3 * r
      ctx.move_to(h, 0.0)
      ctx.line_to(-h, -r)
      ctx.line_to(-h, r)
      ctx.close_path()
    }
    "triangle-left" => {
      let r = size.sqrt() / 2.0
      let h = half_sqrt3 * r
      ctx.move_to(-h, 0.0)
      ctx.line_to(h, -r)
      ctx.line_to(h, r)
      ctx.close_path()
    }
    "stroke" => {
      let r = size.sqrt() / 2.0
      ctx.move_to(-r, 0.0)
      ctx.line_to(r, 0.0)
    }
    other => raise SceneError("unsupported symbol shape: " + other)
  }
}

///|
/// The symbol of one item, drawn at the origin (d3-shape `symbol()` with
/// `type(item.shape || 'circle')` and `size(item.size ?? 64)`).
pub fn draw_item_symbol(ctx : Ctx, item : Item) -> Unit raise SceneError {
  let shape = match item.get("shape") {
    v if v.truthy() => v.to_js_string()
    _ => "circle"
  }
  let size = item.num_or("size", 64.0)
  draw_symbol(ctx, shape, size)
}

///|
fn defined(item : Item) -> Bool {
  match item.get("defined") {
    Bool(false) => false
    _ => true
  }
}

///|
fn make_curve(items : Array[Item]) -> Curve raise SceneError {
  let first = items[0]
  let interp = match first.get("interpolate") {
    v if v.truthy() => v.to_js_string()
    _ => "linear"
  }
  let orient = match first.str("orient") {
    Some(o) => o
    None => ""
  }
  match curve_kind(interp, orient) {
    Some(k) => Curve::new(k)
    None => raise SceneError("unsupported interpolate: " + interp)
  }
}

///|
/// d3-shape `line()` over the items (`x`, `y`, `defined`).
pub fn draw_line(ctx : Ctx, items : Array[Item]) -> Unit raise SceneError {
  if items.length() == 0 {
    return
  }
  let curve = make_curve(items)
  let mut defined0 = false
  let n = items.length()
  for i = 0; i <= n; i = i + 1 {
    let is_def = i < n && defined(items[i])
    if is_def != defined0 {
      defined0 = !defined0
      if defined0 {
        curve.line_start(ctx)
      } else {
        curve.line_end(ctx)
      }
    }
    if defined0 {
      curve.point(ctx, items[i].num0("x"), items[i].num0("y"))
    }
  }
}

///|
/// d3-shape `area()`: vertical areas span `y` to `y + height`, horizontal
/// areas span `x` to `x + width`.
pub fn draw_area(ctx : Ctx, items : Array[Item]) -> Unit raise SceneError {
  if items.length() == 0 {
    return
  }
  let curve = make_curve(items)
  let horizontal = match items[0].str("orient") {
    Some("horizontal") => true
    _ => false
  }
  let n = items.length()
  let x0z : Array[Double] = Array::make(n, 0.0)
  let y0z : Array[Double] = Array::make(n, 0.0)
  let mut defined0 = false
  let mut j = 0
  for i = 0; i <= n; i = i + 1 {
    let is_def = i < n && defined(items[i])
    if is_def != defined0 {
      defined0 = !defined0
      if defined0 {
        j = i
        curve.area_start()
        curve.line_start(ctx)
      } else {
        curve.line_end(ctx)
        curve.line_start(ctx)
        let mut k = i - 1
        while k >= j {
          curve.point(ctx, x0z[k], y0z[k])
          k = k - 1
        }
        curve.line_end(ctx)
        curve.area_end()
      }
    }
    if defined0 {
      let it = items[i]
      if horizontal {
        // y(y).x1(x).x0(xw)
        x0z[i] = it.num0("x") + it.num0("width")
        y0z[i] = it.num0("y")
        curve.point(ctx, it.num0("x"), y0z[i])
      } else {
        // x(x).y1(y).y0(yh)
        x0z[i] = it.num0("x")
        y0z[i] = it.num0("y") + it.num0("height")
        curve.point(ctx, x0z[i], it.num0("y"))
      }
    }
  }
}

// ---- path strings for SVG ----

///|
/// `d` of a rect item (full precision), optionally offset.
pub fn rect_path(item : Item, x? : Double, y? : Double) -> String {
  let p = PathBuf::new()
  draw_rect(Buf(p), item, x0?=x, y0?=y)
  p.to_string()
}

///|
/// `d` of a symbol item, centred on the origin (3 decimals, as d3-shape).
pub fn symbol_path(item : Item) -> String raise SceneError {
  let p = PathBuf::new(digits=3)
  draw_item_symbol(Buf(p), item)
  p.to_string()
}

///|
pub fn line_path(items : Array[Item]) -> String raise SceneError {
  let p = PathBuf::new(digits=3)
  draw_line(Buf(p), items)
  p.to_string()
}

///|
pub fn area_path(items : Array[Item]) -> String raise SceneError {
  let p = PathBuf::new(digits=3)
  draw_area(Buf(p), items)
  p.to_string()
}
