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
        #|{"data":{"values":[]},"mark":"bar","layer":[]}
      ),
    ),
    content="layer 暂不支持",
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
