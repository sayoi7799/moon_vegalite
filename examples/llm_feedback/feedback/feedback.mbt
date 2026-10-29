// What to do with the Vega-Lite a language model wrote:
//   1. take the JSON out of the reply (models wrap it in a ```json fence and add prose),
//   2. if the renderer rejects it, turn the error into a prompt that can be sent straight back.
//
// The error messages of moon_vegalite start with the JSON path of the offending
// property ("encoding.color.condition 暂不支持", "encoding.y.type: 未知的字段类型 x"),
// which is what makes a precise correction request possible.

///|
/// The JSON of a model reply: the body of the first ``` fence if there is one,
/// otherwise everything from the first `{` to the last `}`, otherwise the reply itself.
pub fn extract_json(reply : String) -> String {
  match reply.find("```") {
    Some(open) => {
      let after = reply[open + 3:].to_owned()
      // the rest of the opening line is the language tag ("json")
      let body = match after.find("\n") {
        Some(nl) => after[nl + 1:].to_owned()
        None => after
      }
      match body.find("```") {
        Some(close) => body[:close].to_owned().trim().to_owned()
        None => body.trim().to_owned()
      }
    }
    None =>
      match (reply.find("{"), reply.rev_find("}")) {
        (Some(a), Some(b)) if b > a => reply[a:b + 1].to_owned()
        _ => reply.trim().to_owned()
      }
  }
}

///|
/// A renderer error split into the JSON path it names (when it names one) and the reason.
pub(all) struct ErrorInfo {
  path : String?
  reason : String
}

///|
/// The keys a Vega-Lite specification can start a path with.
let top_keys : Array[String] = [
  "data", "mark", "encoding", "transform", "layer", "width", "height", "title", "config",
  "params", "selection", "hconcat", "vconcat", "concat", "facet", "repeat", "spec",
  "resolve", "background", "padding", "autosize", "description", "datasets", "projection",
  "view", "usermeta", "name",
]

///|
/// Whether `text` is a JSON path such as `encoding.x.scale.type` or `layer[1].mark`.
fn is_path(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  for c in text {
    if c == ' ' || c.to_int() > 127 {
      return false
    }
  }
  let first = match text.find(".") {
    Some(i) => text[:i].to_owned()
    None => text
  }
  let first = match first.find("[") {
    Some(i) => first[:i].to_owned()
    None => first
  }
  top_keys.contains(first)
}

///|
/// Split a message of the renderer: `path: reason`, `path reason`, or a message
/// without a path (a JSON syntax error, for instance).
pub fn split_error(message : String) -> ErrorInfo {
  if message.has_prefix("JSON 解析失败") {
    return { path: None, reason: message, }
  }
  match message.find(": ") {
    Some(i) if is_path(message[:i].to_owned()) =>
      return {
        path: Some(message[:i].to_owned()),
        reason: message[i + 2:].to_owned(),
      }
    _ => ()
  }
  match message.find(" ") {
    Some(i) if is_path(message[:i].to_owned()) =>
      {
        path: Some(message[:i].to_owned()),
        reason: message[i + 1:].to_owned(),
      }
    _ => { path: None, reason: message, }
  }
}

///|
/// A suggestion that fits the kind of error, or an empty string.
fn hint_for(info : ErrorInfo) -> String {
  if info.reason.has_prefix("JSON 解析失败") {
    return "请检查括号、引号和结尾多余的逗号，只返回合法的 JSON，不要加注释。"
  }
  match info.path {
    Some("data.url") =>
      "本渲染器不读取外部文件：请把数据直接写成 data.values 数组。"
    Some("mark") if info.reason.contains("未知") =>
      "可用的 mark：bar、line、point、circle、square、area、rule、tick、rect、text。"
    _ =>
      if info.reason.contains("暂不支持") {
        "该特性在本渲染器里不可用：请删除它，或改用等价的受支持写法（不要使用交互、参数、分面或拼接）。"
      } else if info.reason.contains("未知") {
        "取值不合法：请改成 Vega-Lite 5 中合法的取值。"
      } else if info.reason.contains("缺") {
        "请补上缺失的部分。"
      } else {
        ""
      }
  }
}

///|
/// The correction request for an error message of the renderer: it names the
/// JSON path and the reason and can be sent to the model as it is.
pub fn repair_prompt(message : String) -> String {
  let info = split_error(message)
  let lines : Array[String] = [
    "你上一次给出的 Vega-Lite 规格无法渲染。",
  ]
  match info.path {
    Some(p) => lines.push("出错位置（JSON 路径）：" + p)
    None => lines.push("出错位置：无法定位到某个属性")
  }
  lines.push("原因：" + info.reason)
  let hint = hint_for(info)
  if hint != "" {
    lines.push("建议：" + hint)
  }
  lines.push(
    "请只修改这一处，其余部分保持不变，并且只返回修正后的完整 JSON。",
  )
  lines.join("\n") + "\n"
}
