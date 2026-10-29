///|
let bars : String =
  #|{"data":{"values":[{"a":"A","b":28},{"a":"B","b":55},{"a":"C","b":43}]},
  #| "title":"Bars",
  #| "mark":"bar",
  #| "encoding":{"x":{"field":"a","type":"nominal"},"y":{"field":"b","type":"quantitative"}}}

///|
/// Every `<text ...>...</text>` element of an SVG document, in order.
fn texts_of(svg : String) -> Array[String] {
  let out : Array[String] = []
  let mut rest = svg
  while true {
    match rest.find("<text") {
      None => break
      Some(i) => {
        let tail = rest[i:].to_owned()
        match tail.find("</text>") {
          None => break
          Some(j) => {
            out.push(tail[:j + 7].to_owned())
            rest = tail[j + 7:].to_owned()
          }
        }
      }
    }
  }
  out
}

///|
test "sketch: the same specification and seed give the same bytes" {
  let a = @moon_vegalite.render_svg_sketch(
    bars,
    options=@moon_vegalite.SketchOptions::new(seed=42),
  )
  let b = @moon_vegalite.render_svg_sketch(
    bars,
    options=@moon_vegalite.SketchOptions::new(seed=42),
  )
  assert_eq(a, b)
}

///|
test "sketch: another seed draws another picture" {
  let a = @moon_vegalite.render_svg_sketch(
    bars,
    options=@moon_vegalite.SketchOptions::new(seed=1),
  )
  let b = @moon_vegalite.render_svg_sketch(
    bars,
    options=@moon_vegalite.SketchOptions::new(seed=2),
  )
  assert_true(a != b)
}

///|
test "sketch: the text is exactly the text of the plain rendering" {
  let plain = @moon_vegalite.render_svg(bars)
  let sketch = @moon_vegalite.render_svg_sketch(bars)
  let t = texts_of(plain)
  assert_true(t.length() > 3)
  assert_eq(texts_of(sketch), t)
}

///|
test "sketch: the shapes become curves, the plain rendering has none" {
  let plain = @moon_vegalite.render_svg(bars)
  let sketch = @moon_vegalite.render_svg_sketch(bars)
  // rough.js draws with Bezier curves; the plain rectangles and lines have none
  assert_true(!plain.contains(" C"))
  assert_true(sketch.contains(" C"))
}

///|
test "sketch: render_svg is unchanged by the sketch option existing" {
  // two renderings of the same specification are identical, with or without a sketch in between
  let a = @moon_vegalite.render_svg(bars)
  ignore(@moon_vegalite.render_svg_sketch(bars))
  assert_eq(@moon_vegalite.render_svg(bars), a)
}

///|
test "sketch: unsupported features still fail with their JSON path" {
  let r = try
    @moon_vegalite.render_svg_sketch(
      "{\"data\":{\"values\":[]},\"mark\":\"bar\",\"params\":[{}]}",
    )
  catch {
    e => e.message()
  } noraise {
    _ => "no error"
  }
  assert_eq(r, "params 暂不支持")
}
