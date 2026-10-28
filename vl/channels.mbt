// Non-positional channels: size, opacity, shape and colour, and the symbol
// legends that describe them.

///|
priv enum LegKind {
  Disc(@scale.Ordinal, Array[@value.Value])
  Cont(@scale.Continuous)
}

///|
priv struct LegCh {
  /// "size" | "shape" | "fill" | "stroke" | "opacity"
  channel : String
  pos : Pos
  kind : LegKind
}

///|
let symbol_shapes : Array[String] = [
  "circle", "square", "triangle-up", "cross", "diamond", "triangle-right", "triangle-down",
  "triangle-left",
]

///|
/// A linear scale over the extent of `field`, optionally including zero.
fn extent_scale(
  rows : Array[Map[String, @value.Value]],
  field : String,
  zero : Bool,
  r0 : Double,
  r1 : Double,
) -> @scale.Continuous {
  let c = @scale.Continuous::new(Linear)
  match domain_extent(rows, [field], zero) {
    Some((lo, hi)) => c.domain = [lo, hi]
    None => ()
  }
  c.range = [r0, r1]
  c
}

///|
fn canonical_rank(channel : String) -> Int32 {
  match channel {
    "size" => 0
    "shape" => 1
    "fill" => 2
    "stroke" => 3
    _ => 6
  }
}

///|
/// Symbol legends: channels encoding the same field share one legend.
fn legends_of(
  chs : Array[LegCh],
  mark : String,
  filled : Bool,
  base_color : String,
  has_color_field : Bool,
  default_opacity : Bool,
) -> Array[Legend] raise CompileError {
  let groups : Array[Array[LegCh]] = []
  for c in chs {
    let mut placed = false
    for g in groups {
      if g[0].pos.field == c.pos.field && g[0].pos.title == c.pos.title {
        g.push(c)
        placed = true
        break
      }
    }
    if !placed {
      groups.push([c])
    }
  }
  let out : Array[Legend] = []
  for g in groups {
    let sorted = @transform.stable_sort(g, fn(a, b) {
      let d = canonical_rank(a.channel) - canonical_rank(b.channel)
      if d < 0 {
        -1
      } else if d > 0 {
        1
      } else {
        0
      }
    })
    let canon = sorted[0]
    let has_color = g.any(fn(c) { c.channel == "fill" || c.channel == "stroke" })
    let has_opacity = g.any(fn(c) { c.channel == "opacity" })
    let has_shape = g.any(fn(c) { c.channel == "shape" })
    let has_size = g.any(fn(c) { c.channel == "size" })
    let symbol : Map[String, @value.Value] = Map([("strokeWidth", num(1.5))])
    symbol["shape"] = str(
      if has_shape {
        "circle"
      } else {
        match mark {
          "bar" => "square"
          "circle" | "square" => mark
          _ => "circle"
        }
      },
    )
    if !has_size {
      symbol["size"] = num(100.0)
    }
    if !has_color && has_color_field {
      if filled {
        symbol["fill"] = str("black")
        symbol["fillOpacity"] = num(if default_opacity { 0.7 } else { 1.0 })
        symbol["stroke"] = str("transparent")
      } else {
        symbol["fill"] = str("transparent")
        symbol["stroke"] = str("#888")
      }
    } else if !has_color {
      if filled {
        symbol["fill"] = str(base_color)
      } else {
        symbol["fill"] = str("transparent")
        symbol["stroke"] = str(base_color)
      }
    } else if !g.any(fn(c) { c.channel == "fill" }) {
      symbol["fill"] = str("transparent")
    }
    if !has_opacity && default_opacity {
      symbol["opacity"] = num(0.7)
    }
    let values : Array[@value.Value] = []
    let labels : Array[String] = []
    match canon.kind {
      Disc(_, dom) =>
        for v in dom {
          values.push(v)
          labels.push(v.to_js_string())
        }
      Cont(c) => {
        let d0 = c.domain[0]
        let d1 = c.domain[c.domain.length() - 1]
        let fmt = @format.format_span(d0, d1, 5.0) catch {
          _ => raise CompileError("legend 格式无效")
        }
        for x in c.ticks(count=5.0) {
          values.push(Num(x))
          labels.push(fmt(x))
        }
      }
    }
    let entries = values.mapi(fn(i, v) {
      let props : Map[String, @value.Value] = Map([])
      for c in g {
        let key = match c.channel {
          "fill" | "stroke" | "shape" | "size" | "opacity" => c.channel
          k => k
        }
        match c.kind {
          Disc(o, _) =>
            match o.map(v) {
              Some(x) => props[key] = x
              None => ()
            }
          Cont(sc) =>
            match sc.map(v.to_number()) {
              Some(x) => props[key] = Num(x)
              None => ()
            }
        }
      }
      { label: labels[i], props, }
    })
    out.push(
      build_legend({
        title: Some(canon.pos.title),
        orient: "right",
        symbol,
        entries,
      }),
    )
  }
  out
}
