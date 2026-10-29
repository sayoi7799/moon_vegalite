// The arc shape of d3-shape (`arc()`), as vega-scenegraph uses it for arc marks: circular and annular
// sectors, with `padAngle` and rounded corners. A port of d3-shape 3 `src/arc.js` (ISC). The angles are
// in radians, clockwise from twelve o'clock. Trigonometry is V8's (see `@util.v8_sin`): the digits of
// the path depend on it.

///|
let arc_epsilon : Double = 1.0e-12

///|
let arc_pi : Double = 3.141592653589793

///|
let arc_half_pi : Double = 1.5707963267948966

///|
let arc_tau : Double = 6.283185307179586

///|
fn arc_acos(x : Double) -> Double {
  if x > 1.0 {
    0.0
  } else if x < -1.0 {
    arc_pi
  } else {
    @util.v8_acos(x)
  }
}

///|
fn arc_asin(x : Double) -> Double {
  if x >= 1.0 {
    arc_half_pi
  } else if x <= -1.0 {
    -arc_half_pi
  } else {
    @util.v8_asin(x)
  }
}

///|
fn arc_intersect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> (Double, Double)? {
  let x10 = x1 - x0
  let y10 = y1 - y0
  let x32 = x3 - x2
  let y32 = y3 - y2
  let t = y32 * x10 - x32 * y10
  if t * t < arc_epsilon {
    return None
  }
  let t2 = (x32 * (y0 - y2) - y32 * (x0 - x2)) / t
  Some((x0 + t2 * x10, y0 + t2 * y10))
}

///|
priv struct CornerTangents {
  cx : Double
  cy : Double
  x01 : Double
  y01 : Double
  x11 : Double
  y11 : Double
}

///|
/// The perpendicular offset line of length `rc` (d3-shape `cornerTangents`).
fn corner_tangents(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  r1 : Double,
  rc : Double,
  cw : Bool,
) -> CornerTangents {
  let x01 = x0 - x1
  let y01 = y0 - y1
  let lo = (if cw { rc } else { -rc }) / (x01 * x01 + y01 * y01).sqrt()
  let ox = lo * y01
  let oy = -lo * x01
  let x11 = x0 + ox
  let y11 = y0 + oy
  let x10 = x1 + ox
  let y10 = y1 + oy
  let x00 = (x11 + x10) / 2.0
  let y00 = (y11 + y10) / 2.0
  let dx = x10 - x11
  let dy = y10 - y11
  let d2 = dx * dx + dy * dy
  let r = r1 - rc
  let dd = x11 * y10 - x10 * y11
  let d = (if dy < 0.0 { -1.0 } else { 1.0 }) *
    @util.js_max(0.0, r * r * d2 - dd * dd).sqrt()
  let mut cx0 = (dd * dy - dx * d) / d2
  let mut cy0 = (-dd * dx - dy * d) / d2
  let cx1 = (dd * dy + dx * d) / d2
  let cy1 = (-dd * dx + dy * d) / d2
  let dx0 = cx0 - x00
  let dy0 = cy0 - y00
  let dx1 = cx1 - x00
  let dy1 = cy1 - y00
  // pick the closer of the two intersection points
  if dx0 * dx0 + dy0 * dy0 > dx1 * dx1 + dy1 * dy1 {
    cx0 = cx1
    cy0 = cy1
  }
  {
    cx: cx0,
    cy: cy0,
    x01: -ox,
    y01: -oy,
    x11: cx0 * (r1 / r - 1.0),
    y11: cy0 * (r1 / r - 1.0),
  }
}

///|
/// Draw the arc of an arc item (`startAngle`, `endAngle`, `padAngle`, `innerRadius`,
/// `outerRadius`, `cornerRadius`) around the origin.
pub fn draw_arc(ctx : Ctx, item : Item) -> Unit {
  let mut r0 = item.num0("innerRadius")
  let mut r1 = item.num0("outerRadius")
  let a0 = item.num0("startAngle") - arc_half_pi
  let a1 = item.num0("endAngle") - arc_half_pi
  let da = (a1 - a0).abs()
  let cw = a1 > a0
  // the outer radius is always the larger one
  if r1 < r0 {
    let r = r1
    r1 = r0
    r0 = r
  }
  if !(r1 > arc_epsilon) {
    // a point
    ctx.move_to(0.0, 0.0)
  } else if da > arc_tau - arc_epsilon {
    // a circle or an annulus
    ctx.move_to(r1 * @util.v8_cos(a0), r1 * @util.v8_sin(a0))
    ctx.arc(0.0, 0.0, r1, a0, a1, !cw)
    if r0 > arc_epsilon {
      ctx.move_to(r0 * @util.v8_cos(a1), r0 * @util.v8_sin(a1))
      ctx.arc(0.0, 0.0, r0, a1, a0, cw)
    }
  } else {
    // a circular or annular sector
    let mut a01 = a0
    let mut a11 = a1
    let mut a00 = a0
    let mut a10 = a1
    let mut da0 = da
    let mut da1 = da
    let ap = item.num0("padAngle") / 2.0
    let rp = if ap > arc_epsilon { (r0 * r0 + r1 * r1).sqrt() } else { 0.0 }
    let rc = @util.js_min((r1 - r0).abs() / 2.0, item.num0("cornerRadius"))
    let mut rc0 = rc
    let mut rc1 = rc
    // apply padding? since r1 >= r0, da1 >= da0
    if rp > arc_epsilon {
      let mut p0 = arc_asin(rp / r0 * @util.v8_sin(ap))
      let mut p1 = arc_asin(rp / r1 * @util.v8_sin(ap))
      da0 = da0 - p0 * 2.0
      if da0 > arc_epsilon {
        p0 = p0 * (if cw { 1.0 } else { -1.0 })
        a00 = a00 + p0
        a10 = a10 - p0
      } else {
        da0 = 0.0
        a00 = (a0 + a1) / 2.0
        a10 = a00
      }
      da1 = da1 - p1 * 2.0
      if da1 > arc_epsilon {
        p1 = p1 * (if cw { 1.0 } else { -1.0 })
        a01 = a01 + p1
        a11 = a11 - p1
      } else {
        da1 = 0.0
        a01 = (a0 + a1) / 2.0
        a11 = a01
      }
    }
    let x01 = r1 * @util.v8_cos(a01)
    let y01 = r1 * @util.v8_sin(a01)
    let x10 = r0 * @util.v8_cos(a10)
    let y10 = r0 * @util.v8_sin(a10)
    let mut x11 = 0.0
    let mut y11 = 0.0
    let mut x00 = 0.0
    let mut y00 = 0.0
    // rounded corners?
    if rc > arc_epsilon {
      x11 = r1 * @util.v8_cos(a11)
      y11 = r1 * @util.v8_sin(a11)
      x00 = r0 * @util.v8_cos(a00)
      y00 = r0 * @util.v8_sin(a00)
      // restrict the corner radius according to the sector angle; if this intersection
      // fails the arc is probably too small, so the corner radius is disabled
      if da < arc_pi {
        match arc_intersect(x01, y01, x00, y00, x11, y11, x10, y10) {
          Some((ox, oy)) => {
            let ax = x01 - ox
            let ay = y01 - oy
            let bx = x11 - ox
            let by = y11 - oy
            let kc = 1.0 /
              @util.v8_sin(
                arc_acos(
                  (ax * bx + ay * by) /
                  ((ax * ax + ay * ay).sqrt() * (bx * bx + by * by).sqrt()),
                ) /
                2.0,
              )
            let lc = (ox * ox + oy * oy).sqrt()
            rc0 = @util.js_min(rc, (r0 - lc) / (kc - 1.0))
            rc1 = @util.js_min(rc, (r1 - lc) / (kc + 1.0))
          }
          None => {
            rc0 = 0.0
            rc1 = 0.0
          }
        }
      }
    }
    // is the sector collapsed to a line?
    if !(da1 > arc_epsilon) {
      ctx.move_to(x01, y01)
    } else if rc1 > arc_epsilon {
      // does the outer ring have rounded corners?
      let t0 = corner_tangents(x00, y00, x01, y01, r1, rc1, cw)
      let t1 = corner_tangents(x11, y11, x10, y10, r1, rc1, cw)
      ctx.move_to(t0.cx + t0.x01, t0.cy + t0.y01)
      if rc1 < rc {
        // the corners have merged
        ctx.arc(
          t0.cx,
          t0.cy,
          rc1,
          @util.v8_atan2(t0.y01, t0.x01),
          @util.v8_atan2(t1.y01, t1.x01),
          !cw,
        )
      } else {
        // otherwise: the two corners and the ring
        ctx.arc(
          t0.cx,
          t0.cy,
          rc1,
          @util.v8_atan2(t0.y01, t0.x01),
          @util.v8_atan2(t0.y11, t0.x11),
          !cw,
        )
        ctx.arc(
          0.0,
          0.0,
          r1,
          @util.v8_atan2(t0.cy + t0.y11, t0.cx + t0.x11),
          @util.v8_atan2(t1.cy + t1.y11, t1.cx + t1.x11),
          !cw,
        )
        ctx.arc(
          t1.cx,
          t1.cy,
          rc1,
          @util.v8_atan2(t1.y11, t1.x11),
          @util.v8_atan2(t1.y01, t1.x01),
          !cw,
        )
      }
    } else {
      // the outer ring is just a circular arc
      ctx.move_to(x01, y01)
      ctx.arc(0.0, 0.0, r1, a01, a11, !cw)
    }
    // is there no inner ring, and it is a circular sector?
    // or an annular sector collapsed by padding?
    if !(r0 > arc_epsilon) || !(da0 > arc_epsilon) {
      ctx.line_to(x10, y10)
    } else if rc0 > arc_epsilon {
      // does the inner ring have rounded corners?
      let t0 = corner_tangents(x10, y10, x11, y11, r0, -rc0, cw)
      let t1 = corner_tangents(x01, y01, x00, y00, r0, -rc0, cw)
      ctx.line_to(t0.cx + t0.x01, t0.cy + t0.y01)
      if rc0 < rc {
        ctx.arc(
          t0.cx,
          t0.cy,
          rc0,
          @util.v8_atan2(t0.y01, t0.x01),
          @util.v8_atan2(t1.y01, t1.x01),
          !cw,
        )
      } else {
        ctx.arc(
          t0.cx,
          t0.cy,
          rc0,
          @util.v8_atan2(t0.y01, t0.x01),
          @util.v8_atan2(t0.y11, t0.x11),
          !cw,
        )
        ctx.arc(
          0.0,
          0.0,
          r0,
          @util.v8_atan2(t0.cy + t0.y11, t0.cx + t0.x11),
          @util.v8_atan2(t1.cy + t1.y11, t1.cx + t1.x11),
          cw,
        )
        ctx.arc(
          t1.cx,
          t1.cy,
          rc0,
          @util.v8_atan2(t1.y11, t1.x11),
          @util.v8_atan2(t1.y01, t1.x01),
          !cw,
        )
      }
    } else {
      // the inner ring is just a circular arc
      ctx.arc(0.0, 0.0, r0, a10, a00, cw)
    }
  }
  ctx.close_path()
}

///|
/// `d` of an arc item, centred on the origin (3 decimals, as d3-shape).
pub fn arc_path(item : Item) -> String {
  let p = PathBuf::new(digits=3)
  draw_arc(Buf(p), item)
  p.to_string()
}
