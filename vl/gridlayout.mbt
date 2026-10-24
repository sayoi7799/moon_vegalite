// vega-view-transforms `gridLayout`: arrange groups in rows and columns.

///|
priv struct GridOpt {
  /// "each" | "all" | "" for columns / rows
  align_col : String
  align_row : String
  pad_col : Double
  pad_row : Double
  /// number of columns (0 means one per group)
  columns : Int32
  center_col : Bool
  center_row : Bool
  /// measure groups by their size (`bounds: flush`) instead of their bounds
  flush : Bool
  anchor_x : Double
  anchor_y : Double
  /// "start" | "middle" | "end" for the grid anchor
  anchor_col : String
  anchor_row : String
}

///|
fn bbox_of(item : @scene.Item, flush : Bool) -> @scene.Bounds {
  if flush {
    let b = @scene.Bounds::new()
    ignore(b.set(0.0, 0.0, item.num0("width"), item.num0("height")))
    b
  } else {
    let b = item.bounds.copy()
    if b.is_empty() {
      ignore(b.set(0.0, 0.0, 0.0, 0.0))
    } else {
      ignore(b.translate(-item.num0("x"), -item.num0("y")))
    }
    b
  }
}

///|
fn offset_value(v : Double) -> Double {
  if v < 0.0 {
    ceil(-v)
  } else {
    0.0
  }
}

///|
/// Lay out `groups` (whose containing marks are `marks`), returning the
/// bounds of the resulting grid.
fn grid_layout(
  groups : Array[@scene.Item],
  marks : Array[@scene.Mark],
  o : GridOpt,
) -> @scene.Bounds {
  let n = groups.length()
  let ncols = if o.columns > 0 { o.columns } else { n }
  let nrows = if ncols <= 0 { 1 } else { (n + ncols - 1) / ncols }
  let x_offset : Array[Double] = Array::make(n, 0.0)
  let y_offset : Array[Double] = Array::make(n, 0.0)
  let x_extent : Array[Double] = Array::make(ncols, 0.0)
  let y_extent : Array[Double] = Array::make(nrows, 0.0)
  let dx : Array[Double] = Array::make(n, 0.0)
  let dy : Array[Double] = Array::make(n, 0.0)
  let boxes : Array[@scene.Bounds] = []
  let mut x_max = 0.0
  let mut y_max = 0.0
  for i in 0..<n {
    let g = groups[i]
    let b = bbox_of(g, o.flush)
    boxes.push(b)
    g.set_num("x", g.num0("x"))
    g.set_num("y", g.num0("y"))
    let c = i % ncols
    let r = i / ncols
    let px = ceil(b.x2)
    let py = ceil(b.y2)
    x_max = max(x_max, px)
    y_max = max(y_max, py)
    x_extent[c] = max(x_extent[c], px)
    y_extent[r] = max(y_extent[r], py)
    x_offset[i] = o.pad_col + offset_value(b.x1)
    y_offset[i] = o.pad_row + offset_value(b.y1)
  }
  for i in 0..<n {
    if i % ncols == 0 {
      x_offset[i] = 0.0
    }
    if i < ncols {
      y_offset[i] = 0.0
    }
  }
  let mut align_col = o.align_col
  let mut align_row = o.align_row
  // column alignment
  if align_col == "each" {
    for c in 1..<ncols {
      let mut offset = 0.0
      let mut i = c
      while i < n {
        if offset < x_offset[i] {
          offset = x_offset[i]
        }
        i += ncols
      }
      i = c
      while i < n {
        x_offset[i] = offset + x_extent[c - 1]
        i += ncols
      }
    }
  } else if align_col == "all" {
    let mut offset = 0.0
    for i in 0..<n {
      if i % ncols != 0 && offset < x_offset[i] {
        offset = x_offset[i]
      }
    }
    for i in 0..<n {
      if i % ncols != 0 {
        x_offset[i] = offset + x_max
      }
    }
  } else {
    align_col = ""
    for c in 1..<ncols {
      let mut i = c
      while i < n {
        x_offset[i] = x_offset[i] + x_extent[c - 1]
        i += ncols
      }
    }
  }
  // row alignment
  if align_row == "each" {
    for r in 1..<nrows {
      let mut offset = 0.0
      let m = r * ncols + ncols
      for i in (r * ncols)..<m {
        if i < n && offset < y_offset[i] {
          offset = y_offset[i]
        }
      }
      for i in (r * ncols)..<m {
        if i < n {
          y_offset[i] = offset + y_extent[r - 1]
        }
      }
    }
  } else if align_row == "all" {
    let mut offset = 0.0
    for i in ncols..<n {
      if offset < y_offset[i] {
        offset = y_offset[i]
      }
    }
    for i in ncols..<n {
      y_offset[i] = offset + y_max
    }
  } else {
    align_row = ""
    for r in 1..<nrows {
      for i in (r * ncols)..<(r * ncols + ncols) {
        if i < n {
          y_offset[i] = y_offset[i] + y_extent[r - 1]
        }
      }
    }
  }
  // horizontal layout
  let mut x = 0.0
  for i in 0..<n {
    x = x_offset[i] + (if i % ncols != 0 { x } else { 0.0 })
    dx[i] = dx[i] + (x - groups[i].num0("x"))
  }
  // vertical layout
  for c in 0..<ncols {
    let mut y = 0.0
    let mut i = c
    while i < n {
      y = y + y_offset[i]
      dy[i] = dy[i] + (y - groups[i].num0("y"))
      i += ncols
    }
  }
  // centering
  if align_col != "" && o.center_col && nrows > 1 {
    for i in 0..<n {
      let b = if align_col == "all" { x_max } else { x_extent[i % ncols] }
      let v = b - boxes[i].x2 - groups[i].num0("x") - dx[i]
      if v > 0.0 {
        dx[i] = dx[i] + v / 2.0
      }
    }
  }
  if align_row != "" && o.center_row && ncols != 1 {
    for i in 0..<n {
      let b = if align_row == "all" { y_max } else { y_extent[i / ncols] }
      let v = b - boxes[i].y2 - groups[i].num0("y") - dy[i]
      if v > 0.0 {
        dy[i] = dy[i] + v / 2.0
      }
    }
  }
  // anchor
  let bounds = @scene.Bounds::new()
  ignore(bounds.set(0.0, 0.0, 0.0, 0.0))
  for i in 0..<n {
    ignore(bounds.union(boxes[i].translate(dx[i], dy[i])))
  }
  let mut ax = o.anchor_x
  let mut ay = o.anchor_y
  match o.anchor_col {
    "end" => ax = ax - bounds.width()
    "middle" => ax = ax - bounds.width() / 2.0
    _ => ()
  }
  match o.anchor_row {
    "end" => ay = ay - bounds.height()
    "middle" => ay = ay - bounds.height() / 2.0
    _ => ()
  }
  ax = round(ax)
  ay = round(ay)
  // apply
  ignore(bounds.clear())
  for i in 0..<n {
    ignore(marks[i].bounds.clear())
  }
  for i in 0..<n {
    let g = groups[i]
    dx[i] = dx[i] + ax
    dy[i] = dy[i] + ay
    g.set_num("x", g.num0("x") + dx[i])
    g.set_num("y", g.num0("y") + dy[i])
    ignore(
      bounds.union(marks[i].bounds.union(g.bounds.translate(dx[i], dy[i]))),
    )
  }
  bounds
}
