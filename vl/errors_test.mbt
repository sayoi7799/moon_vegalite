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
    message_of("{" + base + ",\"vconcat\":[{\"mark\":\"point\"}]}"),
    content="vconcat 暂不支持",
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

///|
fn enc(mark : String, encoding : String) -> String {
  "{\"data\":{\"values\":[{\"a\":\"x\",\"b\":1,\"c\":2}]},\"mark\":" +
  mark +
  ",\"encoding\":" +
  encoding +
  "}"
}

///|
test "properties the compiler would ignore are rejected" {
  let xy = "\"x\":{\"field\":\"a\",\"type\":\"nominal\"},\"y\":{\"field\":\"b\",\"type\":\"quantitative\"}"
  // mark properties
  inspect(
    message_of(enc("{\"type\":\"bar\",\"opacity\":0.5}", "{" + xy + "}")),
    content="mark.opacity 暂不支持",
  )
  // config
  inspect(
    message_of(
      "{\"config\":{\"view\":{\"stroke\":null}},\"data\":{\"values\":[]},\"mark\":\"bar\"}",
    ),
    content="config.view 暂不支持",
  )
  // axis, scale, legend and sort details
  inspect(
    message_of(
      enc(
        "\"bar\"", "{\"x\":{\"field\":\"a\",\"type\":\"nominal\",\"axis\":{\"tickCount\":3}},\"y\":{\"field\":\"b\",\"type\":\"quantitative\"}}",
      ),
    ),
    content="encoding.x.axis.tickCount 暂不支持",
  )
  inspect(
    message_of(
      enc(
        "\"bar\"", "{\"x\":{\"field\":\"a\",\"type\":\"nominal\",\"scale\":{\"padding\":0.3}},\"y\":{\"field\":\"b\",\"type\":\"quantitative\"}}",
      ),
    ),
    content="encoding.x.scale.padding 暂不支持",
  )
  inspect(
    message_of(
      enc(
        "\"point\"", "{\"x\":{\"field\":\"b\",\"type\":\"quantitative\",\"sort\":\"descending\"}}",
      ),
    ),
    content="encoding.x.sort 暂不支持",
  )
  inspect(
    message_of(
      enc(
        "\"point\"", "{\"x\":{\"field\":\"b\",\"type\":\"quantitative\"},\"color\":{\"field\":\"a\",\"type\":\"nominal\",\"scale\":{\"scheme\":\"set1\"}}}",
      ),
    ),
    content="encoding.color.scale.scheme 暂不支持",
  )
  inspect(
    message_of(
      enc(
        "\"point\"", "{\"x\":{\"field\":\"b\",\"type\":\"quantitative\"},\"color\":{\"field\":\"a\",\"type\":\"nominal\",\"legend\":{\"orient\":\"bottom\"}}}",
      ),
    ),
    content="encoding.color.legend 暂不支持",
  )
  inspect(
    message_of(
      enc(
        "\"point\"", "{\"x\":{\"field\":\"b\",\"type\":\"quantitative\",\"stack\":\"zero\"}}",
      ),
    ),
    content="encoding.x.stack 暂不支持",
  )
  inspect(
    message_of(
      enc(
        "\"bar\"", "{\"x\":{\"field\":\"a\",\"type\":\"nominal\"},\"size\":{\"field\":\"b\",\"type\":\"quantitative\"}}",
      ),
    ),
    content="encoding.size 暂不支持用于 mark bar",
  )
  inspect(
    message_of(
      enc(
        "\"point\"", "{\"x\":{\"field\":\"b\",\"type\":\"quantitative\"},\"size\":{\"field\":\"a\",\"type\":\"nominal\"}}",
      ),
    ),
    content="encoding.size.type nominal 暂不支持",
  )
}

///|
fn layered(top : String, layers : String) -> String {
  "{\"data\":{\"values\":[{\"a\":1,\"b\":2,\"c\":\"u\"}]}," +
  top +
  "\"layer\":" +
  layers +
  "}"
}

///|
test "layers that cannot be merged yet are rejected with their path" {
  let q = "\"encoding\":{\"x\":{\"field\":\"a\",\"type\":\"quantitative\"},\"y\":{\"field\":\"b\",\"type\":\"quantitative\"}}"
  // an error inside a layer names the layer
  inspect(
    message_of(
      layered(
        "",
        "[{\"mark\":\"point\"," +
        q +
        "},{\"mark\":{\"type\":\"line\",\"opacity\":0.5}," +
        q +
        "}]",
      ),
    ),
    content="layer[1].mark.opacity 暂不支持",
  )
  // independent scales
  inspect(
    message_of(
      layered(
        "\"resolve\":{\"scale\":{\"y\":\"independent\"}},",
        "[{\"mark\":\"point\"," + q + "},{\"mark\":\"line\"," + q + "}]",
      ),
    ),
    content="resolve.scale.y independent 暂不支持",
  )
  // the same non-positional channel in two layers
  inspect(
    message_of(
      layered(
        "", "[{\"mark\":\"point\",\"encoding\":{\"x\":{\"field\":\"a\",\"type\":\"quantitative\"},\"color\":{\"field\":\"c\",\"type\":\"nominal\"}}},{\"mark\":\"point\",\"encoding\":{\"x\":{\"field\":\"a\",\"type\":\"quantitative\"},\"color\":{\"field\":\"c\",\"type\":\"nominal\"}}}]",
      ),
    ),
    content="encoding.color (多个 layer 使用同一通道) 暂不支持",
  )
  // size of a single layer
  inspect(
    message_of(layered("", "[{\"mark\":\"point\",\"width\":100," + q + "}]")),
    content="layer[0].width 暂不支持",
  )
  // incompatible scale types on a shared channel
  inspect(
    message_of(
      layered(
        "", "[{\"mark\":\"point\",\"encoding\":{\"x\":{\"field\":\"a\",\"type\":\"quantitative\"}}},{\"mark\":\"point\",\"encoding\":{\"x\":{\"field\":\"c\",\"type\":\"nominal\"}}}]",
      ),
    ),
    content="layer 间 x 比例尺类型不兼容 (需要 independent) 暂不支持",
  )
  // lines and areas coloured by a field are not drawn per series yet
  inspect(
    message_of(
      enc(
        "\"line\"", "{\"x\":{\"field\":\"a\",\"type\":\"quantitative\"},\"y\":{\"field\":\"b\",\"type\":\"quantitative\"},\"color\":{\"field\":\"c\",\"type\":\"nominal\"}}",
      ),
    ),
    content="encoding.color (line / area 按颜色分组) 暂不支持",
  )
}
