///|
test "render returns the SVG of a valid specification" {
  let svg = @web.render(
    "{\"data\":{\"values\":[{\"a\":\"A\",\"b\":2}]},\"mark\":\"bar\",\"encoding\":{\"x\":{\"field\":\"a\",\"type\":\"nominal\"},\"y\":{\"field\":\"b\",\"type\":\"quantitative\"}}}",
  )
  assert_true(svg.has_prefix("<svg "))
}

///|
test "render reports unsupported features with their JSON path" {
  inspect(
    @web.render("{\"data\":{\"values\":[]},\"mark\":\"bar\",\"params\":[{}]}"),
    content="ERROR: params 暂不支持",
  )
}

///|
test "render reports invalid JSON" {
  assert_true(@web.render("{\"data\": ").has_prefix("ERROR: JSON 解析失败"))
}

///|
test "version is the library version" {
  inspect(@web.version(), content="0.2.0")
}

///|
test "render_sketch draws by hand, the same bytes for the same seed" {
  let spec = "{\"data\":{\"values\":[{\"a\":\"A\",\"b\":2}]},\"mark\":\"bar\",\"encoding\":{\"x\":{\"field\":\"a\",\"type\":\"nominal\"},\"y\":{\"field\":\"b\",\"type\":\"quantitative\"}}}"
  let a = @web.render_sketch(spec, 5, 1.0)
  assert_true(a.has_prefix("<svg "))
  assert_true(a.contains(" C"))
  assert_eq(a, @web.render_sketch(spec, 5, 1.0))
  assert_true(a != @web.render_sketch(spec, 6, 1.0))
  assert_true(a != @web.render(spec))
}

///|
test "render_sketch reports unsupported features like render" {
  inspect(
    @web.render_sketch(
      "{\"data\":{\"values\":[]},\"mark\":\"bar\",\"params\":[{}]}", 1, 1.0,
    ),
    content="ERROR: params 暂不支持",
  )
}
