///|
let tiny : String =
  #|{"data":{"values":[{"a":"A","b":28},{"a":"B","b":55}]},"mark":"bar","encoding":{"x":{"field":"a","type":"nominal"},"y":{"field":"b","type":"quantitative"}}}

///|
test "version is exposed" {
  assert_eq(@moon_vegalite.version(), "0.2.0")
}

///|
test "render_svg produces an SVG document" {
  let svg = @moon_vegalite.render_svg(tiny)
  assert_true(svg.has_prefix("<svg xmlns="))
  assert_true(svg.has_suffix("</svg>"))
}

///|
test "scale multiplies the pixel size only" {
  let c = @moon_vegalite.compile(tiny)
  let one = @moon_vegalite.svg_of(c)
  let two = @moon_vegalite.svg_of(c, scale=2.0)
  assert_true(one.contains("viewBox=\"0 0 "))
  assert_true(
    two.contains(
      "width=\"" + ((c.view_width + 2.0 * c.padding) * 2.0).to_string() + "\"",
    ),
  )
}

///|
test "errors carry a message" {
  let r = try
    @moon_vegalite.render_svg(
      "{\"data\":{\"values\":[{\"a\":1}]},\"vconcat\":[{\"mark\":\"point\"}]}",
    )
  catch {
    e => e.message()
  } noraise {
    _ => ""
  }
  assert_eq(r, "vconcat 暂不支持")
}

///|
test "scene_json exposes view and scene" {
  let j = @moon_vegalite.scene_json(@moon_vegalite.compile(tiny))
  assert_true(j.stringify().has_prefix("{\"view\":{\"width\":"))
}
