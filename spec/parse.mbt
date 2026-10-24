// Parsing and validating a Vega-Lite specification (JSON) into `Spec`.

///|
let supported_marks : Array[String] = [
  "bar", "line", "point", "area", "rule", "tick", "rect", "text",
]

///|
let known_unsupported_marks : Array[String] = [
  "circle", "square", "arc", "trail", "geoshape", "image", "boxplot", "errorbar",
  "errorband",
]

///|
let supported_channels : Array[String] = [
  "x", "y", "x2", "y2", "color", "size", "shape", "opacity", "text",
]

///|
let unsupported_channels : Array[String] = [
  "detail", "order", "tooltip", "href", "key", "fill", "stroke", "strokeWidth", "strokeDash",
  "fillOpacity", "strokeOpacity", "xOffset", "yOffset", "theta", "theta2", "radius",
  "radius2", "latitude", "longitude", "latitude2", "longitude2", "row", "column",
  "facet", "url", "description", "time", "angle", "xError", "yError", "xError2",
  "yError2",
]

///|
/// Mark properties that are implemented (the others are rejected with a path).
let supported_mark_props : Array[String] = [
  "color", "fill", "stroke", "opacity", "fillOpacity", "strokeOpacity", "strokeWidth",
  "strokeDash", "strokeDashOffset", "strokeCap", "strokeJoin", "size", "filled",
  "orient", "interpolate", "tension", "cornerRadius", "cornerRadiusEnd", "cornerRadiusTopLeft",
  "cornerRadiusTopRight", "cornerRadiusBottomLeft", "cornerRadiusBottomRight", "binSpacing",
  "width", "height", "align", "baseline", "dx", "dy", "angle", "font", "fontSize",
  "fontWeight", "fontStyle", "text", "limit", "ellipsis", "lineBreak", "lineHeight",
  "thickness", "minBandSize", "discreteBandSize", "shape", "invalid", "x", "y", "x2",
  "y2", "radius", "blend", "ariaRole",
]

///|
let unsupported_mark_props : Array[String] = [
  "point", "line", "tooltip", "clip", "href", "cursor", "style", "innerRadius", "outerRadius",
  "padAngle", "theta", "theta2", "radius2", "aspect", "url", "smooth", "radiusOffset",
  "thetaOffset", "timeUnitBandPosition", "timeUnitBandSize", "bandSize", "xOffset",
  "yOffset", "x2Offset", "y2Offset", "dir", "description", "ariaRoleDescription",
  "aria", "endAngle", "startAngle", "tooltipContent", "overlay",
]

///|
let supported_scale_props : Array[String] = [
  "type", "domain", "domainMin", "domainMax", "range", "scheme", "zero", "nice",
  "round", "padding", "paddingInner", "paddingOuter", "reverse", "clamp", "base",
  "exponent", "align", "rangeMin", "rangeMax",
]

///|
let supported_axis_props : Array[String] = [
  "orient", "title", "format", "formatType", "labelAngle", "labelOverlap", "labels",
  "ticks", "domain", "grid", "tickCount", "values", "labelPadding", "tickSize", "labelFlush",
  "labelFontSize", "titleFontSize", "titlePadding", "offset", "position", "labelLimit",
  "labelColor", "titleColor", "domainColor", "gridColor", "tickColor", "labelBound",
  "gridDash", "gridWidth", "gridOpacity", "domainWidth", "tickWidth", "tickMinStep",
  "zindex", "labelSeparation", "labelAlign", "labelBaseline", "titleAnchor", "titleAngle",
  "titleAlign", "titleBaseline", "titleFontWeight", "labelFontWeight", "minExtent",
  "maxExtent", "labelOffset", "tickOffset", "tickRound", "tickBand", "bandPosition",
  "titleOpacity", "labelOpacity", "gridCap", "domainCap", "tickCap", "domainDash",
  "tickDash", "domainOpacity", "tickOpacity", "titleLimit", "titleFont", "labelFont",
  "titleX", "titleY",
]

///|
let supported_legend_props : Array[String] = [
  "orient", "title", "format", "formatType", "type", "values", "symbolType", "direction",
  "labelLimit", "titleLimit", "symbolSize", "symbolStrokeWidth", "gradientLength",
  "gradientThickness", "padding", "offset", "tickCount", "fillColor", "labelFontSize",
  "titleFontSize", "titlePadding", "labelOffset", "symbolOffset", "columns", "columnPadding",
  "rowPadding", "clipHeight", "cornerRadius", "strokeColor", "gradientStrokeColor",
  "labelColor", "titleColor", "titleOrient", "titleAnchor", "titleFontWeight", "labelFontWeight",
  "labelAlign", "labelBaseline", "gridAlign", "symbolDirection", "symbolFillColor",
  "symbolStrokeColor", "gradientDirection", "zindex", "labelOverlap",
]

///|
fn check_props(
  path : String,
  props : Map[String, @value.Value],
  supported : Array[String],
) -> Unit raise SpecError {
  for k, _ in props {
    if !supported.contains(k) {
      raise unsupported(join_path(path, k))
    }
  }
}

///|
fn obj_props(
  path : String,
  j : Json,
) -> Map[String, @value.Value] raise SpecError {
  match j {
    Object(m) => {
      let out : Map[String, @value.Value] = Map([])
      for k, v in m {
        out[k] = @value.from_json(v)
      }
      out
    }
    _ => raise invalid(path, "应为对象")
  }
}

///|
fn full_type(path : String, t : String) -> String raise SpecError {
  match t {
    "quantitative" | "Q" | "q" => "quantitative"
    "ordinal" | "O" | "o" => "ordinal"
    "nominal" | "N" | "n" => "nominal"
    "temporal" | "T" | "t" => "temporal"
    "geojson" => raise unsupported(path)
    _ => raise invalid(path, "未知的字段类型 " + t)
  }
}

///|
fn parse_guide(
  r : Reader,
  key : String,
  supported : Array[String],
) -> Guide raise SpecError {
  match r.take(key) {
    None => Default
    Some(Null) => Off
    Some(True) => Props(Map([]))
    Some(False) => Off
    Some(j) => {
      let path = r.path_of(key)
      let props = obj_props(path, j)
      check_props(path, props, supported)
      Props(props)
    }
  }
}

///|
fn parse_channel(path : String, j : Json) -> ChannelDef raise SpecError {
  let r = Reader::new(path, j)
  if r.has("condition") {
    raise unsupported(r.path_of("condition"))
  }
  let field = r.string("field")
  let typ = match r.string("type") {
    Some(t) => Some(full_type(r.path_of("type"), t))
    None => None
  }
  let aggregate = r.string("aggregate")
  let mut binned = false
  let bin : Map[String, @value.Value]? = match r.take("bin") {
    None => None
    Some(False) | Some(Null) => None
    Some(True) => Some(Map([]))
    Some(String("binned")) => {
      binned = true
      Some(Map([]))
    }
    Some(Object(m)) => {
      let props = obj_props(r.path_of("bin"), Json::object(m))
      check_props(r.path_of("bin"), props, [
        "maxbins", "step", "nice", "extent", "base", "divide", "minstep", "anchor",
        "steps",
      ])
      Some(props)
    }
    Some(_) => raise invalid(r.path_of("bin"), "应为 true 或对象")
  }
  let time_unit = match r.take("timeUnit") {
    None => None
    Some(String(s)) => Some(s)
    Some(_) => raise unsupported(r.path_of("timeUnit"))
  }
  let sort = r.value("sort")
  let scale_off = match r.take("scale") {
    Some(Null) => true
    Some(_) | None => false
  }
  let scale = match r.obj.get("scale") {
    Some(Object(_) as o) => {
      let props = obj_props(r.path_of("scale"), o)
      check_props(r.path_of("scale"), props, supported_scale_props)
      Some(props)
    }
    Some(Null) | None => None
    Some(_) => raise invalid(r.path_of("scale"), "应为对象或 null")
  }
  let axis = parse_guide(r, "axis", supported_axis_props)
  let legend = parse_guide(r, "legend", supported_legend_props)
  let title : String?? = match r.take("title") {
    None => None
    Some(Null) => Some(None)
    Some(String(s)) => Some(Some(s))
    Some(_) => raise unsupported(r.path_of("title"))
  }
  let format = match r.take("format") {
    None => None
    Some(String(s)) => Some(s)
    Some(_) => raise unsupported(r.path_of("format"))
  }
  let format_type = r.string("formatType")
  let value = r.value("value")
  let datum = r.value("datum")
  let stack = match r.take("stack") {
    None => None
    Some(Null) | Some(False) => Some("none")
    Some(True) => Some("zero")
    Some(String(s)) => Some(s)
    Some(_) =>
      raise invalid(r.path_of("stack"), "应为字符串、布尔值或 null")
  }
  let band = r.number("band")
  let band_position = r.number("bandPosition")
  r.finish(unsupported_keys=[
    "impute", "header", "labelExpr", "repeat", "bandPosition_", "legendExpr",
  ])
  {
    field,
    typ,
    aggregate,
    bin,
    binned,
    time_unit,
    sort,
    scale,
    scale_off,
    axis,
    legend,
    title,
    format,
    format_type,
    value,
    datum,
    stack,
    band,
    band_position,
  }
}

///|
fn parse_mark(path : String, j : Json) -> Mark raise SpecError {
  match j {
    String(s) => {
      if known_unsupported_marks.contains(s) {
        raise unsupported(path)
      }
      if !supported_marks.contains(s) {
        raise invalid(path, "未知的 mark 类型 " + s)
      }
      { typ: s, props: Map([]), }
    }
    Object(_) => {
      let props = obj_props(path, j)
      let typ = match props.get("type") {
        Some(Str(s)) => s
        _ => raise invalid(join_path(path, "type"), "缺少 mark 类型")
      }
      if known_unsupported_marks.contains(typ) {
        raise unsupported(join_path(path, "type"))
      }
      if !supported_marks.contains(typ) {
        raise invalid(join_path(path, "type"), "未知的 mark 类型 " + typ)
      }
      props.remove("type")
      for k, _ in props {
        if unsupported_mark_props.contains(k) ||
          !supported_mark_props.contains(k) {
          if unsupported_mark_props.contains(k) {
            raise unsupported(join_path(path, k))
          } else {
            raise SpecError(join_path(path, k) + " 未知属性")
          }
        }
      }
      { typ, props, }
    }
    _ => raise invalid(path, "应为字符串或对象")
  }
}

///|
fn string_list(path : String, j : Json) -> Array[String] raise SpecError {
  match j {
    Array(items) => {
      let out : Array[String] = []
      for i in 0..<items.length() {
        match items[i] {
          String(s) => out.push(s)
          _ => raise invalid(index_path(path, i), "应为字符串")
        }
      }
      out
    }
    _ => raise invalid(path, "应为字符串数组")
  }
}

///|
fn parse_predicate(path : String, j : Json) -> Predicate raise SpecError {
  match j {
    String(s) => Expr(s)
    Object(m) => {
      let r = Reader::new(path, j)
      let tu = r.string("timeUnit")
      if tu is Some(_) {
        raise unsupported(r.path_of("timeUnit"))
      }
      if m.contains("and") || m.contains("or") {
        let key = if m.contains("and") { "and" } else { "or" }
        let items = match r.take(key) {
          Some(Array(xs)) => xs
          _ => raise invalid(r.path_of(key), "应为数组")
        }
        r.finish()
        let parts : Array[Predicate] = []
        for i in 0..<items.length() {
          parts.push(
            parse_predicate(index_path(join_path(path, key), i), items[i]),
          )
        }
        return if key == "and" { And(parts) } else { Or(parts) }
      }
      if m.contains("not") {
        let inner = match r.take("not") {
          Some(x) => parse_predicate(r.path_of("not"), x)
          None => raise invalid(path, "缺少 not")
        }
        r.finish()
        return Not(inner)
      }
      if m.contains("param") {
        raise unsupported(join_path(path, "param"))
      }
      let field = match r.string("field") {
        Some(f) => f
        None => raise invalid(path, "缺少 field")
      }
      let tu2 : String? = None
      if m.contains("equal") {
        let v = r.value("equal").unwrap_or(Null)
        r.finish()
        return Equal(field, v, tu2)
      }
      if m.contains("lt") {
        let v = r.value("lt").unwrap_or(Null)
        r.finish()
        return Lt(field, v, tu2)
      }
      if m.contains("lte") {
        let v = r.value("lte").unwrap_or(Null)
        r.finish()
        return Lte(field, v, tu2)
      }
      if m.contains("gt") {
        let v = r.value("gt").unwrap_or(Null)
        r.finish()
        return Gt(field, v, tu2)
      }
      if m.contains("gte") {
        let v = r.value("gte").unwrap_or(Null)
        r.finish()
        return Gte(field, v, tu2)
      }
      if m.contains("range") {
        match r.value("range") {
          Some(Arr(items)) if items.length() == 2 => {
            r.finish()
            return Range(field, items[0], items[1], tu2)
          }
          _ =>
            raise invalid(r.path_of("range"), "应为含两个元素的数组")
        }
      }
      if m.contains("oneOf") {
        match r.value("oneOf") {
          Some(Arr(items)) => {
            r.finish()
            return OneOf(field, items, tu2)
          }
          _ => raise invalid(r.path_of("oneOf"), "应为数组")
        }
      }
      if m.contains("valid") {
        let v = r.boolean("valid").unwrap_or(true)
        r.finish()
        if !v {
          raise unsupported(join_path(path, "valid"))
        }
        return Valid(field)
      }
      raise invalid(path, "无法识别的过滤谓词")
    }
    _ => raise invalid(path, "过滤条件应为字符串或对象")
  }
}

///|
fn parse_transform(path : String, j : Json) -> Transform raise SpecError {
  let r = Reader::new(path, j)
  if r.has("filter") {
    let f = match r.take("filter") {
      Some(String(s)) => FilterSpec::Expr(s)
      Some(x) => FilterSpec::Predicate(parse_predicate(r.path_of("filter"), x))
      None => raise invalid(path, "缺少 filter")
    }
    r.finish()
    return Filter(f)
  }
  if r.has("calculate") {
    let expr = match r.string("calculate") {
      Some(e) => e
      None => raise invalid(r.path_of("calculate"), "应为字符串")
    }
    let as_name = match r.string("as") {
      Some(a) => a
      None => raise invalid(r.path_of("as"), "缺少 as")
    }
    r.finish()
    return Calculate(expr, as_name)
  }
  if r.has("aggregate") {
    let ops : Array[AggregateOp] = []
    let agg_path = r.path_of("aggregate")
    match r.take("aggregate") {
      Some(Array(items)) =>
        for i in 0..<items.length() {
          let ir = Reader::new(index_path(agg_path, i), items[i])
          let op = match ir.string("op") {
            Some(o) => o
            None => raise invalid(ir.path_of("op"), "缺少 op")
          }
          let field = ir.string("field")
          let out = match ir.string("as") {
            Some(a) => a
            None => @transform.measure_name(op, field, None)
          }
          ir.finish()
          if !@transform.is_aggregate_op(op) {
            raise unsupported(ir.path_of("op"))
          }
          ops.push({ op, field, out, })
        }
      _ => raise invalid(agg_path, "应为数组")
    }
    let groupby = match r.take("groupby") {
      Some(g) => string_list(r.path_of("groupby"), g)
      None => []
    }
    r.finish()
    return Aggregate(ops, groupby)
  }
  if r.has("bin") {
    let bin_props : Map[String, @value.Value] = match r.take("bin") {
      Some(True) => Map([])
      Some(Object(_) as o) => obj_props(r.path_of("bin"), o)
      _ => raise invalid(r.path_of("bin"), "应为 true 或对象")
    }
    let field = match r.string("field") {
      Some(f) => f
      None => raise invalid(r.path_of("field"), "缺少 field")
    }
    let as_names = match r.take("as") {
      Some(String(s)) => [s, s + "_end"]
      Some(Array(_) as a) => string_list(r.path_of("as"), a)
      _ => raise invalid(r.path_of("as"), "缺少 as")
    }
    r.finish()
    return Bin(field, bin_props, as_names)
  }
  if r.has("timeUnit") {
    let unit = match r.string("timeUnit") {
      Some(u) => u
      None => raise unsupported(r.path_of("timeUnit"))
    }
    let field = match r.string("field") {
      Some(f) => f
      None => raise invalid(r.path_of("field"), "缺少 field")
    }
    let as_name = match r.string("as") {
      Some(a) => a
      None => raise invalid(r.path_of("as"), "缺少 as")
    }
    r.finish()
    return TimeUnit(unit, field, as_name)
  }
  if r.has("fold") {
    let fields = match r.take("fold") {
      Some(f) => string_list(r.path_of("fold"), f)
      None => []
    }
    let as_names = match r.take("as") {
      Some(a) => string_list(r.path_of("as"), a)
      None => ["key", "value"]
    }
    r.finish()
    return Fold(fields, as_names)
  }
  for k, _ in r.obj {
    raise unsupported(join_path(path, k))
  }
  raise invalid(path, "空的 transform")
}

///|
fn parse_data(
  path : String,
  j : Json,
) -> Array[Map[String, @value.Value]]? raise SpecError {
  let r = Reader::new(path, j)
  if r.has("url") {
    raise unsupported(r.path_of("url"))
  }
  if r.has("name") {
    raise unsupported(r.path_of("name"))
  }
  if r.has("sequence") || r.has("sphere") || r.has("graticule") {
    raise unsupported(path)
  }
  let rows : Array[Map[String, @value.Value]] = []
  match r.take("values") {
    Some(Array(items)) =>
      for i in 0..<items.length() {
        match @value.from_json(items[i]) {
          Obj(m) => rows.push(m)
          _ => raise unsupported(index_path(r.path_of("values"), i))
        }
      }
    Some(_) => raise unsupported(r.path_of("values"))
    None => raise invalid(path, "缺少 values")
  }
  match r.take("format") {
    None => ()
    Some(Object(m)) => {
      // only the default JSON reader is supported
      let fr = Reader::new(r.path_of("format"), Json::object(m))
      match fr.string("type") {
        Some("json") | None => ()
        Some(_) => raise unsupported(fr.path_of("type"))
      }
      fr.finish()
    }
    Some(_) => raise invalid(r.path_of("format"), "应为对象")
  }
  r.finish()
  Some(rows)
}

///|
/// Parse a Vega-Lite specification from parsed JSON.
pub fn parse_spec(j : Json) -> Spec raise SpecError {
  let r = Reader::new("", j)
  r.ignore(["$schema", "description", "name", "usermeta"])
  for
    k in [
      "layer", "facet", "concat", "hconcat", "vconcat", "repeat", "spec", "params",
      "selection", "projection", "resolve", "datasets", "view",
    ] {
    if r.has(k) {
      raise unsupported(k)
    }
  }
  let mark = match r.take("mark") {
    Some(m) => parse_mark("mark", m)
    None => raise SpecError("mark: 缺少 mark（仅支持单视图规格）")
  }
  let encoding : Array[(String, ChannelDef)] = []
  match r.take("encoding") {
    None => ()
    Some(Object(m)) =>
      for k, v in m {
        if unsupported_channels.contains(k) {
          raise unsupported(join_path("encoding", k))
        }
        if !supported_channels.contains(k) {
          raise SpecError(join_path("encoding", k) + " 未知属性")
        }
        encoding.push((k, parse_channel(join_path("encoding", k), v)))
      }
    Some(_) => raise invalid("encoding", "应为对象")
  }
  let transform : Array[Transform] = []
  match r.take("transform") {
    None => ()
    Some(Array(items)) =>
      for i in 0..<items.length() {
        transform.push(parse_transform(index_path("transform", i), items[i]))
      }
    Some(_) => raise invalid("transform", "应为数组")
  }
  let data = match r.take("data") {
    None => None
    Some(Null) => None
    Some(d) => parse_data("data", d)
  }
  let width = r.value("width")
  let height = r.value("height")
  match width {
    Some(Str(_)) => raise unsupported("width")
    _ => ()
  }
  match height {
    Some(Str(_)) => raise unsupported("height")
    _ => ()
  }
  let padding = r.value("padding")
  let background = r.string("background")
  let title = match r.take("title") {
    None => None
    Some(String(s)) => Some(s)
    Some(_) => raise unsupported("title")
  }
  let description = None
  let config : Map[String, @value.Value] = Map([])
  match r.take("config") {
    None => ()
    Some(c) => {
      let props = obj_props("config", c)
      for k, _ in props {
        raise unsupported(join_path("config", k))
      }
      ignore(config)
    }
  }
  r.finish(unsupported_keys=["autosize", "center", "bounds", "spacing", "align"])
  {
    mark,
    encoding,
    transform,
    data,
    width,
    height,
    padding,
    background,
    title,
    description,
    config,
  }
}

///|
/// Parse a specification from JSON text.
pub fn parse_spec_text(text : String) -> Spec raise SpecError {
  let j = @json.parse(text) catch {
    e => raise SpecError("JSON 解析失败: " + e.to_string())
  }
  parse_spec(j)
}
