// d3-shape 3.2 curves used by line and area marks: linear, step,
// step-before, step-after and monotone (X for vertical, Y for horizontal).

///|
pub(all) enum CurveKind {
  Linear
  Step
  StepBefore
  StepAfter
  MonotoneX
  MonotoneY
}

///|
/// Look up an interpolation method by its Vega name.
pub fn curve_kind(name : String, orient : String) -> CurveKind? {
  match name {
    "linear" => Some(Linear)
    "step" => Some(Step)
    "step-before" => Some(StepBefore)
    "step-after" => Some(StepAfter)
    "monotone" =>
      Some(if orient == "horizontal" { MonotoneY } else { MonotoneX })
    _ => None
  }
}

///|
/// Mutable curve state, mirroring d3's curve objects.
pub struct Curve {
  kind : CurveKind
  mut line : Double
  mut point : Int32
  mut x0 : Double
  mut y0 : Double
  mut x1 : Double
  mut y1 : Double
  mut t0 : Double
  mut t : Double
}

///|
pub fn Curve::new(kind : CurveKind) -> Curve {
  let nan = @double.not_a_number
  {
    kind,
    line: nan,
    point: 0,
    x0: nan,
    y0: nan,
    x1: nan,
    y1: nan,
    t0: nan,
    t: match kind {
      Step => 0.5
      StepBefore => 0.0
      StepAfter => 1.0
      _ => 0.0
    },
  }
}

///|
pub fn Curve::area_start(self : Curve) -> Unit {
  self.line = 0.0
}

///|
pub fn Curve::area_end(self : Curve) -> Unit {
  self.line = @double.not_a_number
}

///|
pub fn Curve::line_start(self : Curve, _ctx : Ctx) -> Unit {
  self.point = 0
  match self.kind {
    Step | StepBefore | StepAfter => {
      self.x1 = @double.not_a_number
      self.y1 = @double.not_a_number
    }
    MonotoneX | MonotoneY => {
      self.x0 = @double.not_a_number
      self.x1 = @double.not_a_number
      self.y0 = @double.not_a_number
      self.y1 = @double.not_a_number
      self.t0 = @double.not_a_number
    }
    Linear => ()
  }
}

// MonotoneY draws through a context that swaps x and y.

///|
fn mono_move(ctx : Ctx, swap : Bool, x : Double, y : Double) -> Unit {
  if swap {
    ctx.move_to(y, x)
  } else {
    ctx.move_to(x, y)
  }
}

///|
fn mono_line(ctx : Ctx, swap : Bool, x : Double, y : Double) -> Unit {
  if swap {
    ctx.line_to(y, x)
  } else {
    ctx.line_to(x, y)
  }
}

///|
fn sign(x : Double) -> Double {
  if x < 0.0 {
    -1.0
  } else {
    1.0
  }
}

///|
fn slope3(c : Curve, x2 : Double, y2 : Double) -> Double {
  let h0 = c.x1 - c.x0
  let h1 = x2 - c.x1
  // (h0 || h1 < 0 && -0): a zero step takes the sign of the other step
  let d0 = if h0 != 0.0 && !h0.is_nan() {
    h0
  } else if h1 < 0.0 {
    -0.0
  } else {
    0.0
  }
  let d1 = if h1 != 0.0 && !h1.is_nan() {
    h1
  } else if h0 < 0.0 {
    -0.0
  } else {
    0.0
  }
  let s0 = (c.y1 - c.y0) / d0
  let s1 = (y2 - c.y1) / d1
  let p = (s0 * h1 + s1 * h0) / (h0 + h1)
  let m = @util.js_min(@util.js_min(s0.abs(), s1.abs()), 0.5 * p.abs())
  let r = (sign(s0) + sign(s1)) * m
  if r == 0.0 || r.is_nan() {
    0.0
  } else {
    r
  }
}

///|
fn slope2(c : Curve, t : Double) -> Double {
  let h = c.x1 - c.x0
  if h != 0.0 && !h.is_nan() {
    (3.0 * (c.y1 - c.y0) / h - t) / 2.0
  } else {
    t
  }
}

///|
fn mono_point(
  ctx : Ctx,
  swap : Bool,
  c : Curve,
  t0 : Double,
  t1 : Double,
) -> Unit {
  let x0 = c.x0
  let y0 = c.y0
  let x1 = c.x1
  let y1 = c.y1
  let dx = (x1 - x0) / 3.0
  if swap {
    ctx.bezier_to(y0 + dx * t0, x0 + dx, y1 - dx * t1, x1 - dx, y1, x1)
  } else {
    ctx.bezier_to(x0 + dx, y0 + dx * t0, x1 - dx, y1 - dx * t1, x1, y1)
  }
}

///|
pub fn Curve::line_end(self : Curve, ctx : Ctx) -> Unit {
  match self.kind {
    Linear => {
      if (self.line != 0.0 && !self.line.is_nan()) ||
        (self.line != 0.0 && self.point == 1) {
        ctx.close_path()
      }
      self.line = 1.0 - self.line
    }
    Step | StepBefore | StepAfter => {
      if 0.0 < self.t && self.t < 1.0 && self.point == 2 {
        ctx.line_to(self.x1, self.y1)
      }
      if (self.line != 0.0 && !self.line.is_nan()) ||
        (self.line != 0.0 && self.point == 1) {
        ctx.close_path()
      }
      if self.line >= 0.0 {
        self.t = 1.0 - self.t
        self.line = 1.0 - self.line
      }
    }
    MonotoneX | MonotoneY => {
      let swap = self.kind is MonotoneY
      if self.point == 2 {
        mono_line(ctx, swap, self.x1, self.y1)
      } else if self.point == 3 {
        mono_point(ctx, swap, self, self.t0, slope2(self, self.t0))
      }
      if (self.line != 0.0 && !self.line.is_nan()) ||
        (self.line != 0.0 && self.point == 1) {
        ctx.close_path()
      }
      self.line = 1.0 - self.line
    }
  }
}

///|
pub fn Curve::point(self : Curve, ctx : Ctx, x0 : Double, y0 : Double) -> Unit {
  match self.kind {
    Linear =>
      if self.point == 0 {
        self.point = 1
        if self.line != 0.0 && !self.line.is_nan() {
          ctx.line_to(x0, y0)
        } else {
          ctx.move_to(x0, y0)
        }
      } else {
        self.point = 2
        ctx.line_to(x0, y0)
      }
    Step | StepBefore | StepAfter => {
      if self.point == 0 {
        self.point = 1
        if self.line != 0.0 && !self.line.is_nan() {
          ctx.line_to(x0, y0)
        } else {
          ctx.move_to(x0, y0)
        }
      } else {
        self.point = 2
        if self.t <= 0.0 {
          ctx.line_to(self.x1, y0)
          ctx.line_to(x0, y0)
        } else {
          let xm = self.x1 * (1.0 - self.t) + x0 * self.t
          ctx.line_to(xm, self.y1)
          ctx.line_to(xm, y0)
        }
      }
      self.x1 = x0
      self.y1 = y0
    }
    MonotoneX | MonotoneY => {
      let swap = self.kind is MonotoneY
      // MonotoneY feeds (y, x) into the MonotoneX algorithm
      let x = if swap { y0 } else { x0 }
      let y = if swap { x0 } else { y0 }
      if x == self.x1 && y == self.y1 {
        return
      }
      let mut t1 = @double.not_a_number
      match self.point {
        0 => {
          self.point = 1
          if self.line != 0.0 && !self.line.is_nan() {
            mono_line(ctx, swap, x, y)
          } else {
            mono_move(ctx, swap, x, y)
          }
        }
        1 => self.point = 2
        2 => {
          self.point = 3
          t1 = slope3(self, x, y)
          mono_point(ctx, swap, self, slope2(self, t1), t1)
        }
        _ => {
          t1 = slope3(self, x, y)
          mono_point(ctx, swap, self, self.t0, t1)
        }
      }
      self.x0 = self.x1
      self.x1 = x
      self.y0 = self.y1
      self.y1 = y
      self.t0 = t1
    }
  }
}
