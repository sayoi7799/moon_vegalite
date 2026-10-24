// Axis-aligned bounding boxes, as vega-scenegraph's `Bounds`.

///|
pub struct Bounds {
  mut x1 : Double
  mut y1 : Double
  mut x2 : Double
  mut y2 : Double
}

///|
let max_value : Double = 1.7976931348623157e308

///|
/// An empty box (inverted infinite extent).
pub fn Bounds::new() -> Bounds {
  { x1: max_value, y1: max_value, x2: -max_value, y2: -max_value, }
}

///|
pub fn Bounds::copy(self : Bounds) -> Bounds {
  { x1: self.x1, y1: self.y1, x2: self.x2, y2: self.y2, }
}

///|
pub fn Bounds::clear(self : Bounds) -> Bounds {
  self.x1 = max_value
  self.y1 = max_value
  self.x2 = -max_value
  self.y2 = -max_value
  self
}

///|
pub fn Bounds::is_empty(self : Bounds) -> Bool {
  self.x1 == max_value &&
  self.y1 == max_value &&
  self.x2 == -max_value &&
  self.y2 == -max_value
}

///|
pub fn Bounds::set(
  self : Bounds,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Bounds {
  if x2 < x1 {
    self.x2 = x1
    self.x1 = x2
  } else {
    self.x1 = x1
    self.x2 = x2
  }
  if y2 < y1 {
    self.y2 = y1
    self.y1 = y2
  } else {
    self.y1 = y1
    self.y2 = y2
  }
  self
}

///|
pub fn Bounds::add(self : Bounds, x : Double, y : Double) -> Bounds {
  if x < self.x1 {
    self.x1 = x
  }
  if y < self.y1 {
    self.y1 = y
  }
  if x > self.x2 {
    self.x2 = x
  }
  if y > self.y2 {
    self.y2 = y
  }
  self
}

///|
pub fn Bounds::expand(self : Bounds, d : Double) -> Bounds {
  self.x1 = self.x1 - d
  self.y1 = self.y1 - d
  self.x2 = self.x2 + d
  self.y2 = self.y2 + d
  self
}

///|
pub fn Bounds::translate(self : Bounds, dx : Double, dy : Double) -> Bounds {
  self.x1 = self.x1 + dx
  self.x2 = self.x2 + dx
  self.y1 = self.y1 + dy
  self.y2 = self.y2 + dy
  self
}

///|
pub fn Bounds::union(self : Bounds, b : Bounds) -> Bounds {
  if b.x1 < self.x1 {
    self.x1 = b.x1
  }
  if b.y1 < self.y1 {
    self.y1 = b.y1
  }
  if b.x2 > self.x2 {
    self.x2 = b.x2
  }
  if b.y2 > self.y2 {
    self.y2 = b.y2
  }
  self
}

///|
pub fn Bounds::intersect(self : Bounds, b : Bounds) -> Bounds {
  if b.x1 > self.x1 {
    self.x1 = b.x1
  }
  if b.y1 > self.y1 {
    self.y1 = b.y1
  }
  if b.x2 < self.x2 {
    self.x2 = b.x2
  }
  if b.y2 < self.y2 {
    self.y2 = b.y2
  }
  self
}

///|
pub fn Bounds::encloses(self : Bounds, b : Bounds) -> Bool {
  self.x1 <= b.x1 && self.x2 >= b.x2 && self.y1 <= b.y1 && self.y2 >= b.y2
}

///|
pub fn Bounds::width(self : Bounds) -> Double {
  self.x2 - self.x1
}

///|
pub fn Bounds::height(self : Bounds) -> Double {
  self.y2 - self.y1
}

///|
/// The four corners of the box rotated by `angle` radians about (x, y), as
/// [x, y] pairs flattened into eight numbers.
pub fn Bounds::rotated_points(
  self : Bounds,
  angle : Double,
  x : Double,
  y : Double,
) -> Array[Double] {
  let cos = @util.js_cos(angle)
  let sin = @util.js_sin(angle)
  let cx = x - x * cos + y * sin
  let cy = y - x * sin - y * cos
  [
    cos * self.x1 - sin * self.y1 + cx,
    sin * self.x1 + cos * self.y1 + cy,
    cos * self.x1 - sin * self.y2 + cx,
    sin * self.x1 + cos * self.y2 + cy,
    cos * self.x2 - sin * self.y1 + cx,
    sin * self.x2 + cos * self.y1 + cy,
    cos * self.x2 - sin * self.y2 + cx,
    sin * self.x2 + cos * self.y2 + cy,
  ]
}

///|
pub fn Bounds::rotate(
  self : Bounds,
  angle : Double,
  x : Double,
  y : Double,
) -> Bounds {
  let p = self.rotated_points(angle, x, y)
  self.clear().add(p[0], p[1]).add(p[2], p[3]).add(p[4], p[5]).add(p[6], p[7])
}
