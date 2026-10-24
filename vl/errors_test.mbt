// Unsupported features and malformed input fail with a message that names
// the JSON path.

///|
fn message_of(text : String) -> String {
  try @vl.compile(text) catch {
    e => e.message()
  } noraise {
    _ => "no error"
  }
}

///|
test "invalid JSON is reported" {
  inspect(
    message_of("{\"data\": ").has_prefix("JSON 解析失败"),
    content="true",
  )
  inspect(message_of("").has_prefix("JSON 解析失败"), content="true")
}

///|
test "unsupported top-level features name their path" {
  let base = "\"data\":{\"values\":[{\"a\":1}]}"
  inspect(
    message_of(
      "{" + base + ",\"mark\":\"point\",\"params\":[{\"name\":\"p\"}]}",
    ),
    content="params 暂不支持",
  )
  inspect(
    message_of("{" + base + ",\"layer\":[{\"mark\":\"point\"}]}"),
    content="layer 暂不支持",
  )
  inspect(
    message_of(
      "{" + base + ",\"facet\":{\"row\":{\"field\":\"a\"}},\"spec\":{}}",
    ),
    content="facet 暂不支持",
  )
  inspect(
    message_of("{" + base + ",\"hconcat\":[]}"),
    content="hconcat 暂不支持",
  )
  inspect(
    message_of("{\"data\":{\"url\":\"cars.json\"},\"mark\":\"point\"}"),
    content="data.url 暂不支持",
  )
  inspect(
    message_of("{" + base + ",\"mark\":\"geoshape\"}"),
    content="mark 暂不支持",
  )
}

///|
test "unsupported encoding features name their path" {
  let head = "{\"data\":{\"values\":[{\"a\":1}]},\"mark\":\"point\",\"encoding\":"
  inspect(
    message_of(head + "{\"tooltip\":{\"field\":\"a\"}}}"),
    content="encoding.tooltip 暂不支持",
  )
  inspect(
    message_of(
      head +
      "{\"color\":{\"field\":\"a\",\"condition\":{\"param\":\"p\",\"value\":\"red\"}}}}",
    ),
    content="encoding.color.condition 暂不支持",
  )
  inspect(
    message_of(
      head +
      "{\"x\":{\"field\":\"a\",\"type\":\"quantitative\",\"scale\":{\"type\":\"foo\"}}}}",
    ),
    content="encoding.x.scale.type: 未知的 scale 类型 foo",
  )
  inspect(
    message_of(
      head +
      "{\"x\":{\"field\":\"a\",\"type\":\"quantitative\",\"scale\":{\"type\":\"symlog\"}}}}",
    ),
    content="encoding.x.scale.type 暂不支持",
  )
}
