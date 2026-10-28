// Features that are accepted by the specification reader but not implemented
// by the compiler must fail loudly instead of being ignored: every check here
// names the JSON path of the property.

///|
fn nope(path : String) -> CompileError {
  CompileError(path + " 暂不支持")
}

///|
let honoured_mark_props : Array[String] = [
  "color", "filled", "interpolate", "opacity",
]

///|
/// Mark properties that only mean something for `text`.
let honoured_text_props : Array[String] = [
  "align", "baseline", "dx", "dy", "fontSize", "text", "x", "y",
]

///|
/// Mark properties that only mean something for `rule` (`size` also for `line`).
let honoured_rule_props : Array[String] = ["strokeDash", "size"]

///|
let honoured_axis_props : Array[String] = [
  "domain", "domainColor", "domainWidth", "format", "formatType", "grid", "gridColor",
  "gridWidth", "labelAlign", "labelAngle", "labelBaseline", "labelColor", "labelFlush",
  "labelFontSize", "labelLimit", "labelOffset", "labelOverlap", "labelPadding", "labelSeparation",
  "labels", "maxExtent", "minExtent", "offset", "position", "tickColor", "tickMinStep",
  "tickOffset", "tickRound", "tickSize", "tickWidth", "ticks", "titlePadding",
]

///|
let honoured_scale_props : Array[String] = [
  "type", "base", "exponent", "domain", "domainMin", "domainMax", "zero", "range",
  "reverse", "clamp", "nice",
]

///|
/// The field type a channel resolves to (vega-lite's inference).
fn inferred_type(d : @spec.ChannelDef) -> String {
  match d.typ {
    Some(t) => t
    None =>
      if d.datum is Some(Num(_)) {
        "quantitative"
      } else if d.aggregate is Some(_) {
        "quantitative"
      } else if d.time_unit is Some(_) {
        "temporal"
      } else if d.bin is Some(_) {
        "quantitative"
      } else {
        match d.scale {
          Some(m) =>
            match m.get("type") {
              Some(Str("log"))
              | Some(Str("linear"))
              | Some(Str("sqrt"))
              | Some(Str("pow")) => "quantitative"
              Some(Str("time")) | Some(Str("utc")) => "temporal"
              _ => "nominal"
            }
          None => "nominal"
        }
      }
  }
}

///|
fn validate_config(
  config : Map[String, @value.Value],
) -> Unit raise CompileError {
  for k, v in config {
    if k == "scale" {
      match v {
        Obj(m) =>
          for sk, sv in m {
            if sk != "zero" || !(sv is Bool(_)) {
              raise nope("config.scale." + sk)
            }
          }
        _ => raise nope("config.scale")
      }
    } else {
      raise nope("config." + k)
    }
  }
}

///|
pub fn validate(spec : @spec.Spec) -> Unit raise CompileError {
  for k, _ in spec.mark.props {
    if !honoured_mark_props.contains(k) &&
      !(spec.mark.typ == "text" && honoured_text_props.contains(k)) &&
      !(spec.mark.typ == "rule" && honoured_rule_props.contains(k)) &&
      !(spec.mark.typ == "line" && k == "size") {
      raise nope("mark." + k)
    }
  }
  match spec.mark.props.get("size") {
    Some(Num(_)) | None => ()
    Some(_) => raise nope("mark.size")
  }
  if spec.mark.typ == "text" {
    // constant position ("width" / "height" or pixels) and constant text
    match spec.mark.props.get("x") {
      Some(Num(_)) | Some(Str("width")) | None => ()
      Some(_) => raise nope("mark.x")
    }
    match spec.mark.props.get("y") {
      Some(Num(_)) | Some(Str("height")) | None => ()
      Some(_) => raise nope("mark.y")
    }
    match spec.mark.props.get("text") {
      Some(Str(_)) | None => ()
      Some(_) => raise nope("mark.text")
    }
  }
  match spec.mark.props.get("strokeDash") {
    Some(Arr(a)) if a.all(fn(v) { v is Num(_) }) => ()
    None => ()
    Some(_) => raise nope("mark.strokeDash")
  }
  validate_config(spec.config)
  let mark = spec.mark.typ
  // a continuous colour sharing its field with another legend channel makes
  // vega-lite merge them into one symbol legend, which is not implemented
  for e in spec.encoding {
    let (name, d) = e
    if name == "color" &&
      inferred_type(d) == "quantitative" &&
      d.field is Some(_) {
      for o in spec.encoding {
        if o.0 != "color" &&
          (o.0 == "size" || o.0 == "opacity" || o.0 == "shape") &&
          o.1.field == d.field {
          raise nope("encoding." + o.0 + " (与连续颜色共用字段)")
        }
      }
    }
  }
  for e in spec.encoding {
    let (name, d) = e
    let path = "encoding." + name
    let positional = name == "x" || name == "y"
    let typ = inferred_type(d)
    if d.sort is Some(_) &&
      !(positional && (typ == "nominal" || typ == "ordinal")) {
      raise nope(path + ".sort")
    }
    match d.stack {
      Some("none") => ()
      Some(o) =>
        if !(positional && (mark == "bar" || mark == "area")) ||
          !(o == "zero" || o == "normalize" || o == "center") {
          raise nope(path + ".stack")
        }
      None => ()
    }
    if d.band is Some(_) {
      raise nope(path + ".band")
    }
    if d.band_position is Some(_) {
      raise nope(path + ".bandPosition")
    }
    // only these marks know how to draw a binned field (bars as a range,
    // points and text at the middle of the bin)
    if d.bin is Some(_) &&
      !(mark == "bar" ||
      mark == "point" ||
      mark == "circle" ||
      mark == "square" ||
      mark == "text") {
      raise nope(path + ".bin (mark " + mark + ")")
    }
    match d.datum {
      Some(Num(_)) =>
        if !positional || (d.typ is Some(_) && typ != "quantitative") {
          raise nope(path + ".datum")
        }
      Some(_) => raise nope(path + ".datum")
      None => ()
    }
    if d.format_type is Some(_) {
      raise nope(path + ".formatType")
    }
    if d.format is Some(_) && name != "text" {
      raise nope(path + ".format")
    }
    if d.scale_off {
      raise nope(path + ".scale")
    }
    if d.legend is Props(_) {
      raise nope(path + ".legend")
    }
    if (d.bin is Some(_) || d.time_unit is Some(_)) && !positional {
      raise nope(path + (if d.bin is Some(_) { ".bin" } else { ".timeUnit" }))
    }
    match d.axis {
      Props(m) => {
        if !positional {
          raise nope(path + ".axis")
        }
        for k, _ in m {
          if !honoured_axis_props.contains(k) {
            raise nope(path + ".axis." + k)
          }
        }
      }
      _ => ()
    }
    match d.scale {
      Some(m) => {
        let allowed = positional &&
          typ != "nominal" &&
          typ != "ordinal" &&
          d.bin is None
        for k, _ in m {
          if !allowed || !honoured_scale_props.contains(k) {
            raise nope(path + ".scale." + k)
          }
          if typ == "temporal" && k != "type" {
            raise nope(path + ".scale." + k)
          }
        }
      }
      None => ()
    }
    match name {
      "x2" | "y2" =>
        if mark != "rule" && mark != "bar" && mark != "rect" {
          raise nope(path + " (mark " + mark + ")")
        }
      "text" => if mark != "text" { raise nope(path + " (mark " + mark + ")") }
      "color" =>
        if d.field is Some(_) &&
          typ != "nominal" &&
          typ != "ordinal" &&
          typ != "quantitative" {
          raise nope(path + ".type " + typ)
        }
      "size" | "opacity" =>
        if d.field is Some(_) && typ != "quantitative" {
          raise nope(path + ".type " + typ)
        }
      "shape" =>
        if d.field is Some(_) && typ != "nominal" {
          raise nope(path + ".type " + typ)
        }
      _ => ()
    }
  }
}
