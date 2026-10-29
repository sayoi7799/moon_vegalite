///|
test "extract_json takes the body of a code fence" {
  let reply = "好的，如下：\n\n```json\n{\"mark\": \"bar\"}\n```\n\n还可以改颜色。"
  inspect(@feedback.extract_json(reply), content="{\"mark\": \"bar\"}")
}

///|
test "extract_json works with a fence without a language tag" {
  inspect(@feedback.extract_json("```\n{\"a\": 1}\n```"), content="{\"a\": 1}")
}

///|
test "extract_json reads an unterminated fence to the end" {
  inspect(@feedback.extract_json("```json\n{\"a\": 1}\n"), content="{\"a\": 1}")
}

///|
test "extract_json cuts plain JSON out of surrounding prose" {
  inspect(
    @feedback.extract_json("Here you go: {\"a\": {\"b\": 2}} Enjoy!"),
    content="{\"a\": {\"b\": 2}}",
  )
}

///|
test "extract_json returns a reply without JSON unchanged" {
  inspect(
    @feedback.extract_json("  sorry, I cannot  "),
    content="sorry, I cannot",
  )
}

///|
test "split_error: path and reason separated by a space" {
  let i = @feedback.split_error("encoding.color.condition 暂不支持")
  assert_eq(i.path, Some("encoding.color.condition"))
  inspect(i.reason, content="暂不支持")
}

///|
test "split_error: path and reason separated by a colon" {
  let i = @feedback.split_error(
    "encoding.y.type: 未知的字段类型 quantitave",
  )
  assert_eq(i.path, Some("encoding.y.type"))
  inspect(i.reason, content="未知的字段类型 quantitave")
}

///|
test "split_error: layer paths and top-level keys" {
  let i = @feedback.split_error("layer[1].mark.cornerRadius 暂不支持")
  assert_eq(i.path, Some("layer[1].mark.cornerRadius"))
  let j = @feedback.split_error("data 缺失")
  assert_eq(j.path, Some("data"))
  inspect(j.reason, content="缺失")
}

///|
test "split_error: a syntax error and a message without a path have none" {
  let i = @feedback.split_error(
    "JSON 解析失败: Invalid character '}' at line 1, column 42",
  )
  assert_eq(i.path, None)
  inspect(
    i.reason,
    content="JSON 解析失败: Invalid character '}' at line 1, column 42",
  )
  let j = @feedback.split_error("channel 缺少 field")
  assert_eq(j.path, None)
  inspect(j.reason, content="channel 缺少 field")
}

///|
test "repair_prompt names the path, the reason and a hint" {
  inspect(
    @feedback.repair_prompt("data.url 暂不支持"),
    content=(
      #|你上一次给出的 Vega-Lite 规格无法渲染。
      #|出错位置（JSON 路径）：data.url
      #|原因：暂不支持
      #|建议：本渲染器不读取外部文件：请把数据直接写成 data.values 数组。
      #|请只修改这一处，其余部分保持不变，并且只返回修正后的完整 JSON。
      #|
    ),
  )
}

///|
test "repair_prompt for a syntax error has no path" {
  let p = @feedback.repair_prompt(
    "JSON 解析失败: Invalid character '}' at line 1, column 42",
  )
  assert_true(p.contains("出错位置：无法定位到某个属性"))
  assert_true(p.contains("line 1, column 42"))
  assert_true(p.contains("结尾多余的逗号"))
}
