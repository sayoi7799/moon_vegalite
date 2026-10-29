// Hand-drawn rendering: the graphic shapes of a scenegraph (rectangles, lines, paths,
// symbols) are drawn by moon_rough, a port of rough.js; text stays as it is.
//
//   let draw = @sketch.shape_drawer(@sketch.SketchOptions::new(seed=42))
//   @svg.render_svg(scene, @svg.SvgOptions::new(w, h, shapes=draw))
//
// Every shape gets a seed of its own, derived from the base seed and the position of the
// shape in the scenegraph (see `shape_seed`), so the same scenegraph and base seed always
// give the same bytes, and editing one shape does not change the others.

///|
/// How rough.js fills a shape: `Hachure` (the default), `Solid`, `Zigzag`, `CrossHatch`, `Dots`,
/// `Dashed` or `ZigzagLine`.
pub using @moon_rough {type FillStyle}

///|
/// Options of the hand-drawn style.
pub struct SketchOptions {
  /// the base seed; each shape derives its own from it
  seed : Int32
  /// how far the lines stray from the true shape (rough.js `roughness`, default 1)
  roughness : Double
  /// how much the lines bow (rough.js `bowing`, default 1)
  bowing : Double
  fill_style : FillStyle
  /// distance between hachure lines; rough.js uses four times the stroke width when absent
  hachure_gap : Double?
  /// width of the hachure lines; rough.js uses half the stroke width when absent
  fill_weight : Double?
}

///|
pub fn SketchOptions::new(
  seed~ : Int32 = 1,
  roughness~ : Double = 1.0,
  bowing~ : Double = 1.0,
  fill_style~ : FillStyle = Hachure,
  hachure_gap? : Double,
  fill_weight? : Double,
) -> SketchOptions {
  { seed, roughness, bowing, fill_style, hachure_gap, fill_weight, }
}

///|
/// One round of a 32-bit integer hash (the "lowbias" finaliser), computed in `Int64`.
fn mix(x : Int64) -> Int64 {
  let m = 0xFFFFFFFFL
  let mut h = x & m
  h = ((h ^ (h >> 16)) * 0x45D9F3BL) & m
  h = ((h ^ (h >> 16)) * 0x45D9F3BL) & m
  h ^ (h >> 16)
}

///|
/// The seed of the shape at `position` (see `@svg.Shape`): the base seed is hashed together
/// with every index of the position, and the result lies in `[1, 2^31 - 2]`, the range of
/// rough.js' generator (0 would mean "random"). Seeds are hashed, not added, because the
/// first numbers the generator draws from neighbouring seeds are almost equal.
pub fn shape_seed(base : Int32, position : Array[Int32]) -> Int32 {
  let mut h = mix(base.to_int64())
  for i in position {
    h = mix(h * 31L + i.to_int64() + 1L)
  }
  (h % 2147483646L).to_int() + 1
}

///|
priv enum Paint {
  Nothing
  Solid(String)
  Gradient
}

///|
fn paint_of(item : @scene.Item, key : String) -> Paint {
  match item.get(key) {
    Null | Undef => Nothing
    Str("none") | Str("transparent") => Nothing
    Str(c) => Solid(c)
    Obj(_) => Gradient
    v => Solid(v.to_js_string())
  }
}

///|
fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
fn dash_of(item : @scene.Item) -> Array[Double]? {
  match item.get("strokeDash") {
    Arr(a) if a.length() > 0 => {
      let out : Array[Double] = []
      for v in a {
        out.push(v.to_number())
      }
      Some(out)
    }
    _ => None
  }
}

///|
/// The `opacity` of the wrapper element: the item's opacity, times its fill opacity when the
/// shape has no stroke (its outline and hatching then stand for the fill).
fn opacity_of(item : @scene.Item, fill_only : Bool) -> Double? {
  let base = item.opt_num("opacity")
  let fill = if fill_only { item.opt_num("fillOpacity") } else { None }
  match (base, fill) {
    (None, None) => None
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (Some(a), Some(b)) => Some(a * b)
  }
}

///|
/// Draw one shape: the markup replacing the standard element, `None` to keep the
/// standard element (gradients, shapes rough cannot draw).
fn draw_shape(o : SketchOptions, shape : @svg.Shape) -> String? {
  let item = shape.item
  let fill = paint_of(item, "fill")
  let stroke = paint_of(item, "stroke")
  if fill is Gradient || stroke is Gradient {
    return None
  }
  // a shape with a fill but no stroke gets an outline in the colour of its fill
  let (stroke_color, stroke_width, fill_only) = match (stroke, fill) {
    (Solid(c), _) => (c, item.num_or("strokeWidth", 1.0), false)
    (Nothing, Solid(c)) => (c, 1.0, true)
    _ => ("none", 0.0, false)
  }
  let fill_color = match fill {
    Solid(c) => Some(c)
    _ => None
  }
  if stroke_color == "none" && fill_color is None {
    return Some("") // nothing to see
  }
  let seed = shape_seed(o.seed, shape.position)
  let options = @moon_rough.Options::new(
    seed~,
    roughness=o.roughness,
    bowing=o.bowing,
    stroke=stroke_color,
    stroke_width~,
    fill?=fill_color,
    fill_style=o.fill_style,
    hachure_gap?=o.hachure_gap,
    fill_weight?=o.fill_weight,
    stroke_line_dash?=dash_of(item),
  )
  let gen = @moon_rough.generator(
    source=@moon_rough.RandomSource::park_miller(seed),
  )
  let drawable = match shape.geometry {
    Box(x, y, w, h) => {
      if !(finite(x) && finite(y) && finite(w) && finite(h)) {
        return Some("")
      }
      // rough.js wants a positive size
      let x0 = if w < 0.0 { x + w } else { x }
      let y0 = if h < 0.0 { y + h } else { y }
      gen.rectangle(x0, y0, w.abs(), h.abs(), options~)
    }
    Segment(x1, y1, x2, y2) => {
      if !(finite(x1) && finite(y1) && finite(x2) && finite(y2)) {
        return Some("")
      }
      gen.line(x1, y1, x2, y2, options~)
    }
    Path(d) => {
      if d == "" {
        return Some("")
      }
      gen.path(d, options~) catch {
        _ => return None
      }
    }
  }
  let inner = @moon_rough.drawable_to_svg(drawable)
  let attrs = StringBuilder()
  match shape.transform {
    Some(t) => attrs.write_string(" transform=\"" + t + "\"")
    None => ()
  }
  match opacity_of(item, fill_only) {
    Some(a) =>
      attrs.write_string(" opacity=\"" + @util.js_number_to_string(a) + "\"")
    None => ()
  }
  let a = attrs.to_string()
  if a == "" {
    Some(inner)
  } else {
    Some("<g" + a + ">" + inner + "</g>")
  }
}

///|
/// The function to pass as `shapes` to `@svg.SvgOptions::new`.
pub fn shape_drawer(options : SketchOptions) -> (@svg.Shape) -> String? {
  fn(shape) { draw_shape(options, shape) }
}
