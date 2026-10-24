// Bounding boxes of marks and items (vega-scenegraph `bound/*` and the
// `bound` function of every mark type).

///|
let deg_to_rad : Double = 3.141592653589793 / 180.0

///|
/// vega `boundStroke`: grow by the stroke width when the item is stroked.
pub fn bound_stroke(bounds : Bounds, item : Item) -> Bounds {
  let stroked = item.truthy("stroke") &&
    !(item.get("opacity") is Num(0.0)) &&
    !(item.get("strokeOpacity") is Num(0.0))
  if stroked {
    bounds.expand(item.num_or("strokeWidth", 1.0))
  } else {
    bounds
  }
}

///|
fn nan_to_zero(x : Double) -> Double {
  if x.is_nan() || x == 0.0 {
    0.0
  } else {
    x
  }
}

///|
fn bound_rect(bounds : Bounds, item : Item) -> Bounds {
  let x = item.num0("x")
  let y = item.num0("y")
  let x2 = nan_to_zero(x + item.get("width").to_number())
  let y2 = nan_to_zero(y + item.get("height").to_number())
  bound_stroke(bounds.set(x, y, x2, y2), item)
}

///|
fn bound_rule(bounds : Bounds, item : Item) -> Bounds {
  let x1 = item.num0("x")
  let y1 = item.num0("y")
  let x2 = match item.opt_num("x2") {
    Some(v) => v
    None => x1
  }
  let y2 = match item.opt_num("y2") {
    Some(v) => v
    None => y1
  }
  bound_stroke(bounds.set(x1, y1, x2, y2), item)
}

///|
fn bound_text(bounds : Bounds, item : Item) -> Bounds {
  let mut h = font_size(item)
  let x = item.num0("x")
  let y = item.num0("y")
  let mut dx = item.num0("dx")
  let dy = item.num0("dy") + baseline_offset(item) - @util.js_round(0.8 * h)
  let w = match text_lines(item) {
    Lines(lines) => {
      h = h + line_height(item) * (lines.length() - 1).to_double()
      let mut m = 0.0
      for l in lines {
        m = @util.js_max(m, text_width(item, l))
      }
      m
    }
    Single(v) => text_width(item, v)
  }
  match item.str("align") {
    Some("center") => dx = dx - w / 2.0
    Some("right") => dx = dx - w
    _ => ()
  }
  dx = dx + x
  let top = dy + y
  ignore(bounds.set(dx, top, dx + w, top + h))
  let angle = item.num0("angle")
  if angle != 0.0 {
    ignore(bounds.rotate(angle * deg_to_rad, x, y))
  }
  bounds
}

///|
fn bound_symbol(bounds : Bounds, item : Item) -> Bounds raise SceneError {
  let ctx = Bound(BoundCtx::new(bounds, deg=item.num0("angle")))
  draw_item_symbol(ctx, item)
  bound_stroke(bounds, item).translate(item.num0("x"), item.num0("y"))
}

///|
fn bound_group(bounds : Bounds, group : Item) -> Bounds {
  let clip = group.truthy("clip")
  if !clip {
    for m in group.children {
      ignore(bounds.union(m.bounds))
    }
  }
  if (clip || group.truthy("width") || group.truthy("height")) &&
    !group.truthy("noBound") {
    ignore(bounds.add(0.0, 0.0).add(group.num0("width"), group.num0("height")))
  }
  ignore(bound_stroke(bounds, group))
  bounds.translate(group.num0("x"), group.num0("y"))
}

///|
/// Compute bounds bottom-up for a mark and everything below it.
pub fn bound_mark(mark : Mark) -> Unit raise SceneError {
  match mark.marktype {
    Line | Area => {
      ignore(mark.bounds.clear())
      if mark.items.length() > 0 {
        let ctx = Bound(BoundCtx::new(mark.bounds))
        if mark.marktype is Line {
          draw_line(ctx, mark.items)
        } else {
          draw_area(ctx, mark.items)
        }
        ignore(bound_stroke(mark.bounds, mark.items[0]))
      }
    }
    _ => {
      ignore(mark.bounds.clear())
      for item in mark.items {
        ignore(item.bounds.clear())
        match mark.marktype {
          Group => {
            for child in item.children {
              bound_mark(child)
            }
            ignore(bound_group(item.bounds, item))
          }
          Rect => ignore(bound_rect(item.bounds, item))
          Rule => ignore(bound_rule(item.bounds, item))
          Text => ignore(bound_text(item.bounds, item))
          Symbol => ignore(bound_symbol(item.bounds, item))
          _ => ()
        }
        ignore(mark.bounds.union(item.bounds))
      }
    }
  }
}
