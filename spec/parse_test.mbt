///|
fn err_of(text : String) -> String {
  try @spec.parse_spec_text(text) catch {
    @spec.SpecError(m) => m
  } noraise {
    _ => ""
  }
}

///|
test "parses a basic bar chart" {
  let s = @spec.parse_spec_text(
    (
      #|{"data":{"values":[{"a":"A","b":28}]},"mark":"bar","encoding":{"x":{"field":"a","type":"nominal"},"y":{"field":"b","type":"quantitative"}}}
    ),
  )
  inspect(s.mark.typ, content="bar")
  inspect(s.encoding.length(), content="2")
  inspect(s.data.unwrap().length(), content="1")
}

///|
test "unsupported features name their JSON path" {
  inspect(
    err_of(
      (
        #|{"data":{"values":[]},"mark":"bar","encoding":{"color":{"field":"a","condition":{}}}}
      ),
    ),
    content="encoding.color.condition 暂不支持",
  )
  inspect(
    err_of(
      (
        #|{"data":{"values":[]},"facet":{"row":{"field":"a"}},"spec":{}}
      ),
    ),
    content="facet 暂不支持",
  )
  inspect(
    err_of(
      (
        #|{"data":{"url":"x.csv"},"mark":"bar"}
      ),
    ),
    content="data.url 暂不支持",
  )
}

///|
test "invalid JSON is reported" {
  inspect(err_of("{").length() > 0, content="true")
}

///|
test "layers are parsed with their resolve and nested layers" {
  let s = @spec.parse_spec_text(
    (
      #|{"data":{"values":[{"a":1}]},"encoding":{"x":{"field":"a","type":"quantitative"}},"layer":[{"mark":"line"},{"layer":[{"mark":"point"},{"mark":"rule","encoding":{"y":{"field":"a","type":"quantitative"}}}]}],"resolve":{"scale":{"y":"independent"},"legend":{"color":"shared"}}}
    ),
  )
  inspect(s.layer.length(), content="2")
  inspect(s.layer[0].mark.typ, content="line")
  inspect(s.layer[1].layer.length(), content="2")
  inspect(s.layer[1].layer[1].mark.typ, content="rule")
  inspect(s.layer[1].layer[1].encoding.length(), content="1")
  inspect(s.encoding.length(), content="1")
  inspect(s.mark.typ, content="")
  assert_eq(s.resolve.scale.get("y"), Some("independent"))
  assert_eq(s.resolve.legend.get("color"), Some("shared"))
}

///|
test "errors inside layers carry the path of the layer" {
  inspect(
    err_of(
      (
        #|{"data":{"values":[]},"layer":[{"mark":"point"},{"mark":"point","encoding":{"tooltip":{"field":"a"}}}]}
      ),
    ),
    content="layer[1].encoding.tooltip 暂不支持",
  )
  inspect(
    err_of(
      (
        #|{"data":{"values":[]},"layer":[{"layer":[{"mark":"point","params":[]}]}]}
      ),
    ),
    content="layer[0].layer[0].params 暂不支持",
  )
  inspect(
    err_of(
      (
        #|{"data":{"values":[]},"layer":[{"mark":"point","encoding":{"color":{"field":"a","condition":{}}}}]}
      ),
    ),
    content="layer[0].encoding.color.condition 暂不支持",
  )
}

///|
test "malformed layer and resolve specifications" {
  inspect(err_of("{\"layer\":[]}"), content="layer: 不能为空")
  inspect(err_of("{\"layer\":3}"), content="layer: 应为数组")
  inspect(
    err_of("{\"mark\":\"bar\",\"layer\":[{\"mark\":\"point\"}]}"),
    content="mark 不能与 layer 同时出现",
  )
  inspect(
    err_of(
      "{\"layer\":[{\"mark\":\"point\"}],\"resolve\":{\"scale\":{\"x\":\"both\"}}}",
    ),
    content="resolve.scale.x: 应为 shared 或 independent",
  )
  inspect(
    err_of("{\"mark\":\"bar\",\"resolve\":{}}"),
    content="resolve 只能用于 layer",
  )
  inspect(err_of("{\"encoding\":{}}"), content="mark: 缺少 mark")
}
