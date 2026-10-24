// Path building. Shapes draw through the `PathCtx` interface, which has two
// implementations: `PathBuf` (SVG path text, as d3-path 3.1) and `BoundCtx`
// (bounding boxes, as vega-scenegraph's `boundContext`).

///|
let tau : Double = 6.283185307179586

///|
let half_pi : Double = 1.5707963267948966

///|
let epsilon : Double = 1.0e-6

///|
let tau_epsilon : Double = 6.283185307179586 - 1.0e-6

// ---- SVG path text ----

///|
/// d3-path's `Path`: appends SVG path commands; with `digits` coordinates are
/// rounded to that many decimals (d3-shape's default is 3, vega's own
/// rectangle shape uses full precision).
pub struct PathBuf {
  out : StringBuilder
  digits : Int32?
  mut x0 : Double
  mut y0 : Double
  mut x1 : Double
  mut y1 : Double
  mut started : Bool
}

///|
pub fn PathBuf::new(digits? : Int32) -> PathBuf {
  {
    out: StringBuilder(),
    digits,
    x0: 0.0,
    y0: 0.0,
    x1: 0.0,
    y1: 0.0,
    started: false,
  }
}

///|
fn PathBuf::num(self : PathBuf, x : Double) -> String {
  match self.digits {
    None => @util.js_number_to_string(x)
    Some(d) => {
      let mut k = 1.0
      for _ in 0..<d {
        k = k * 10.0
      }
      @util.js_number_to_string(@util.js_round(x * k) / k)
    }
  }
}

///|
pub fn PathBuf::to_string(self : PathBuf) -> String {
  self.out.to_string()
}

///|
pub fn PathBuf::move_to(self : PathBuf, x : Double, y : Double) -> Unit {
  self.x0 = x
  self.x1 = x
  self.y0 = y
  self.y1 = y
  self.started = true
  self.out.write_string("M" + self.num(x) + "," + self.num(y))
}

///|
pub fn PathBuf::close_path(self : PathBuf) -> Unit {
  if self.started {
    self.x1 = self.x0
    self.y1 = self.y0
    self.out.write_string("Z")
  }
}

///|
pub fn PathBuf::line_to(self : PathBuf, x : Double, y : Double) -> Unit {
  self.x1 = x
  self.y1 = y
  self.out.write_string("L" + self.num(x) + "," + self.num(y))
}

///|
pub fn PathBuf::quad_to(
  self : PathBuf,
  x1 : Double,
  y1 : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.x1 = x
  self.y1 = y
  self.out.write_string(
    "Q" +
    self.num(x1) +
    "," +
    self.num(y1) +
    "," +
    self.num(x) +
    "," +
    self.num(y),
  )
}

///|
pub fn PathBuf::bezier_to(
  self : PathBuf,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x : Double,
  y : Double,
) -> Unit {
  self.x1 = x
  self.y1 = y
  self.out.write_string(
    "C" +
    self.num(x1) +
    "," +
    self.num(y1) +
    "," +
    self.num(x2) +
    "," +
    self.num(y2) +
    "," +
    self.num(x) +
    "," +
    self.num(y),
  )
}

///|
pub fn PathBuf::arc(
  self : PathBuf,
  x : Double,
  y : Double,
  r : Double,
  a0 : Double,
  a1 : Double,
  ccw : Bool,
) -> Unit {
  let dx = r * @util.js_cos(a0)
  let dy = r * @util.js_sin(a0)
  let px = x + dx
  let py = y + dy
  let cw = if ccw { 0 } else { 1 }
  let mut da = if ccw { a0 - a1 } else { a1 - a0 }
  if !self.started {
    self.x1 = px
    self.y1 = py
    self.x0 = px
    self.y0 = py
    self.started = true
    self.out.write_string("M" + self.num(px) + "," + self.num(py))
  } else if (self.x1 - px).abs() > epsilon || (self.y1 - py).abs() > epsilon {
    self.x1 = px
    self.y1 = py
    self.out.write_string("L" + self.num(px) + "," + self.num(py))
  }
  if r == 0.0 {
    return
  }
  if da < 0.0 {
    da = da.mod(tau) + tau
  }
  let rs = self.num(r)
  if da > tau_epsilon {
    self.x1 = px
    self.y1 = py
    self.out.write_string(
      "A" +
      rs +
      "," +
      rs +
      ",0,1," +
      cw.to_string() +
      "," +
      self.num(x - dx) +
      "," +
      self.num(y - dy) +
      "A" +
      rs +
      "," +
      rs +
      ",0,1," +
      cw.to_string() +
      "," +
      self.num(px) +
      "," +
      self.num(py),
    )
  } else if da > epsilon {
    let ex = x + r * @util.js_cos(a1)
    let ey = y + r * @util.js_sin(a1)
    self.x1 = ex
    self.y1 = ey
    self.out.write_string(
      "A" +
      rs +
      "," +
      rs +
      ",0," +
      (if da >= 3.141592653589793 { "1" } else { "0" }) +
      "," +
      cw.to_string() +
      "," +
      self.num(ex) +
      "," +
      self.num(ey),
    )
  }
}

///|
pub fn PathBuf::rect(
  self : PathBuf,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  self.x0 = x
  self.x1 = x
  self.y0 = y
  self.y1 = y
  self.started = true
  self.out.write_string(
    "M" +
    self.num(x) +
    "," +
    self.num(y) +
    "h" +
    self.num(w) +
    "v" +
    self.num(h) +
    "h" +
    self.num(-w) +
    "Z",
  )
}

// ---- bounding boxes ----

///|
/// vega-scenegraph's `boundContext`: accumulates the extent of a path,
/// optionally rotated by `deg` degrees about the origin.
pub struct BoundCtx {
  bounds : Bounds
  rot : Double
  ma : Double
  mb : Double
  mc : Double
  md : Double
  mut lx : Double
  mut ly : Double
}

///|
pub fn BoundCtx::new(bounds : Bounds, deg~ : Double = 0.0) -> BoundCtx {
  if deg != 0.0 && !deg.is_nan() {
    let rot = deg * deg_to_rad_const
    let c = @util.js_cos(rot)
    let s = @util.js_sin(rot)
    { bounds, rot, ma: c, mb: s, mc: -s, md: c, lx: 0.0, ly: 0.0, }
  } else {
    { bounds, rot: 0.0, ma: 1.0, mb: 0.0, mc: 0.0, md: 1.0, lx: 0.0, ly: 0.0, }
  }
}

///|
let deg_to_rad_const : Double = 3.141592653589793 / 180.0

///|
fn BoundCtx::px(self : BoundCtx, x : Double, y : Double) -> Double {
  self.ma * x + self.mc * y
}

///|
fn BoundCtx::py(self : BoundCtx, x : Double, y : Double) -> Double {
  self.mb * x + self.md * y
}

///|
fn BoundCtx::add_l(self : BoundCtx, x : Double, y : Double) -> Unit {
  self.lx = x
  self.ly = y
  ignore(self.bounds.add(x, y))
}

///|
fn BoundCtx::add_pl(self : BoundCtx, x : Double, y : Double) -> Unit {
  self.add_l(self.px(x, y), self.py(x, y))
}

///|
fn BoundCtx::add_p(self : BoundCtx, x : Double, y : Double) -> Unit {
  ignore(self.bounds.add(self.px(x, y), self.py(x, y)))
}

///|
pub fn BoundCtx::move_to(self : BoundCtx, x : Double, y : Double) -> Unit {
  self.add_pl(x, y)
}

///|
pub fn BoundCtx::line_to(self : BoundCtx, x : Double, y : Double) -> Unit {
  self.add_pl(x, y)
}

///|
pub fn BoundCtx::close_path(_self : BoundCtx) -> Unit {
  ()
}

///|
pub fn BoundCtx::rect(
  self : BoundCtx,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  if self.rot != 0.0 {
    self.add_p(x + w, y)
    self.add_p(x + w, y + h)
    self.add_p(x, y + h)
    self.add_pl(x, y)
  } else {
    ignore(self.bounds.add(x + w, y + h))
    self.add_l(x, y)
  }
}

///|
fn quad_extrema(
  x0 : Double,
  x1 : Double,
  x2 : Double,
  cb : (Double) -> Unit,
) -> Unit {
  let t = (x0 - x1) / (x0 + x2 - 2.0 * x1)
  if 0.0 < t && t < 1.0 {
    cb(x0 + (x1 - x0) * t)
  }
}

///|
fn cubic_at(
  t : Double,
  x0 : Double,
  x1 : Double,
  x2 : Double,
  x3 : Double,
) -> Double {
  let s = 1.0 - t
  let s2 = s * s
  let t2 = t * t
  s2 * s * x0 + 3.0 * s2 * t * x1 + 3.0 * s * t2 * x2 + t2 * t * x3
}

///|
fn cubic_extrema(
  x0 : Double,
  x1 : Double,
  x2 : Double,
  x3 : Double,
  cb : (Double) -> Unit,
) -> Unit {
  let a = x3 - x0 + 3.0 * x1 - 3.0 * x2
  let b = x0 + x2 - 2.0 * x1
  let c = x0 - x1
  let mut t0 = 0.0
  let mut t1 = 0.0
  if a.abs() > 1.0e-14 {
    let r = b * b + c * a
    if r >= 0.0 {
      let sr = r.sqrt()
      t0 = (-b + sr) / a
      t1 = (-b - sr) / a
    }
  } else {
    t0 = 0.5 * c / b
  }
  if 0.0 < t0 && t0 < 1.0 {
    cb(cubic_at(t0, x0, x1, x2, x3))
  }
  if 0.0 < t1 && t1 < 1.0 {
    cb(cubic_at(t1, x0, x1, x2, x3))
  }
}

///|
pub fn BoundCtx::quad_to(
  self : BoundCtx,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Unit {
  let px1 = self.px(x1, y1)
  let py1 = self.py(x1, y1)
  let px2 = self.px(x2, y2)
  let py2 = self.py(x2, y2)
  quad_extrema(self.lx, px1, px2, fn(x) {
    ignore(self.bounds.add(x, self.bounds.y1))
  })
  quad_extrema(self.ly, py1, py2, fn(y) {
    ignore(self.bounds.add(self.bounds.x1, y))
  })
  self.add_l(px2, py2)
}

///|
pub fn BoundCtx::bezier_to(
  self : BoundCtx,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  let px1 = self.px(x1, y1)
  let py1 = self.py(x1, y1)
  let px2 = self.px(x2, y2)
  let py2 = self.py(x2, y2)
  let px3 = self.px(x3, y3)
  let py3 = self.py(x3, y3)
  cubic_extrema(self.lx, px1, px2, px3, fn(x) {
    ignore(self.bounds.add(x, self.bounds.y1))
  })
  cubic_extrema(self.ly, py1, py2, py3, fn(y) {
    ignore(self.bounds.add(self.bounds.x1, y))
  })
  self.add_l(px3, py3)
}

///|
pub fn BoundCtx::arc(
  self : BoundCtx,
  cx : Double,
  cy : Double,
  r : Double,
  sa0 : Double,
  ea0 : Double,
  ccw0 : Bool,
) -> Unit {
  let mut sa = sa0 + self.rot
  let mut ea = ea0 + self.rot
  let mut ccw = ccw0
  self.lx = r * @util.js_cos(ea) + cx
  self.ly = r * @util.js_sin(ea) + cy
  if (ea - sa).abs() > tau - 1.0e-8 {
    ignore(self.bounds.add(cx - r, cy - r))
    ignore(self.bounds.add(cx + r, cy + r))
  } else {
    let update = fn(a : Double) {
      ignore(
        self.bounds.add(r * @util.js_cos(a) + cx, r * @util.js_sin(a) + cy),
      )
    }
    update(sa)
    update(ea)
    if ea != sa {
      sa = sa.mod(tau)
      if sa < 0.0 {
        sa = sa + tau
      }
      ea = ea.mod(tau)
      if ea < 0.0 {
        ea = ea + tau
      }
      if ea < sa {
        ccw = !ccw
        let s = sa
        sa = ea
        ea = s
      }
      if ccw {
        ea = ea - tau
        let mut s = sa - sa.mod(half_pi)
        let mut i = 0
        while i < 4 && s > ea {
          update(s)
          i = i + 1
          s = s - half_pi
        }
      } else {
        let mut s = sa - sa.mod(half_pi) + half_pi
        let mut i = 0
        while i < 4 && s < ea {
          update(s)
          i = i + 1
          s = s + half_pi
        }
      }
    }
  }
}

// ---- one drawing target ----

///|
/// Where a shape draws: SVG path text or a bounding box.
pub enum Ctx {
  Buf(PathBuf)
  Bound(BoundCtx)
}

///|
pub fn Ctx::move_to(self : Ctx, x : Double, y : Double) -> Unit {
  match self {
    Buf(p) => p.move_to(x, y)
    Bound(b) => b.move_to(x, y)
  }
}

///|
pub fn Ctx::line_to(self : Ctx, x : Double, y : Double) -> Unit {
  match self {
    Buf(p) => p.line_to(x, y)
    Bound(b) => b.line_to(x, y)
  }
}

///|
pub fn Ctx::quad_to(
  self : Ctx,
  x1 : Double,
  y1 : Double,
  x : Double,
  y : Double,
) -> Unit {
  match self {
    Buf(p) => p.quad_to(x1, y1, x, y)
    Bound(b) => b.quad_to(x1, y1, x, y)
  }
}

///|
pub fn Ctx::bezier_to(
  self : Ctx,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x : Double,
  y : Double,
) -> Unit {
  match self {
    Buf(p) => p.bezier_to(x1, y1, x2, y2, x, y)
    Bound(b) => b.bezier_to(x1, y1, x2, y2, x, y)
  }
}

///|
pub fn Ctx::arc(
  self : Ctx,
  x : Double,
  y : Double,
  r : Double,
  a0 : Double,
  a1 : Double,
  ccw : Bool,
) -> Unit {
  match self {
    Buf(p) => p.arc(x, y, r, a0, a1, ccw)
    Bound(b) => b.arc(x, y, r, a0, a1, ccw)
  }
}

///|
pub fn Ctx::rect(
  self : Ctx,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  match self {
    Buf(p) => p.rect(x, y, w, h)
    Bound(b) => b.rect(x, y, w, h)
  }
}

///|
pub fn Ctx::close_path(self : Ctx) -> Unit {
  match self {
    Buf(p) => p.close_path()
    Bound(b) => b.close_path()
  }
}
