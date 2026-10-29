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
  inspect(@web.version(), content="0.1.0")
}
