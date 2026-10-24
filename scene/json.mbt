// Reading and writing scenegraphs as JSON, in the same shape as
// vega-scenegraph's `sceneToJSON` (marks with `marktype` and `items`; group
// items carry their child marks in `items`).

///|
fn json_field(m : Map[String, Json], k : String) -> Json? {
  m.get(k)
}

///|
/// Build a mark (and everything below it) from JSON.
pub fn mark_from_json(j : Json) -> Mark raise SceneError {
  let m = match j {
    Object(m) => m
    _ => raise SceneError("scene mark must be an object")
  }
  let typename = match json_field(m, "marktype") {
    Some(String(s)) => s
    _ => raise SceneError("scene mark has no marktype")
  }
  let marktype = match MarkType::from_name(typename) {
    Some(t) => t
    None => raise SceneError("unsupported mark type: " + typename)
  }
  let name = match json_field(m, "name") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let role = match json_field(m, "role") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let interactive = match json_field(m, "interactive") {
    Some(False) => false
    _ => true
  }
  let clip = match json_field(m, "clip") {
    Some(True) => true
    _ => false
  }
  let zindex = match json_field(m, "zindex") {
    Some(Number(x, ..)) => Some(x.to_int())
    _ => None
  }
  let aria = match json_field(m, "aria") {
    Some(False) => false
    _ => true
  }
  let items : Array[Item] = []
  match json_field(m, "items") {
    Some(Array(list)) =>
      for it in list {
        match it {
          Object(o) => {
            let item = Item::new()
            for k, v in o {
              if k == "items" && marktype is Group {
                match v {
                  Array(children) =>
                    for c in children {
                      item.children.push(mark_from_json(c))
                    }
                  _ => ()
                }
              } else {
                item.props[k] = @value.from_json(v)
              }
            }
            items.push(item)
          }
          _ => raise SceneError("scene item must be an object")
        }
      }
    _ => ()
  }
  Mark::new(marktype, name?, role?, interactive~, clip~, zindex?, aria~, items~)
}

///|
fn value_to_json(v : @value.Value) -> Json {
  match v {
    Null | Undef => Json::null()
    Bool(b) => Json::boolean(b)
    Num(x) =>
      if x.is_nan() || x.is_inf() {
        Json::null()
      } else {
        Json::number(x)
      }
    Str(s) => Json::string(s)
    Arr(items) => Json::array(items.map(value_to_json))
    Obj(m) => {
      let o : Map[String, Json] = Map([])
      for k, x in m {
        o[k] = value_to_json(x)
      }
      Json::object(o)
    }
  }
}

///|
fn bounds_to_json(b : Bounds) -> Json {
  let o : Map[String, Json] = Map([])
  o["x1"] = Json::number(b.x1)
  o["y1"] = Json::number(b.y1)
  o["x2"] = Json::number(b.x2)
  o["y2"] = Json::number(b.y2)
  Json::object(o)
}

///|
/// Serialise a mark. With `with_bounds`, every mark and item carries its
/// bounding box under `bounds`.
pub fn mark_to_json(mark : Mark, with_bounds~ : Bool = false) -> Json {
  let o : Map[String, Json] = Map([])
  o["marktype"] = Json::string(mark.marktype.name())
  match mark.name {
    Some(n) => o["name"] = Json::string(n)
    None => ()
  }
  match mark.role {
    Some(r) => o["role"] = Json::string(r)
    None => ()
  }
  o["interactive"] = Json::boolean(mark.interactive)
  o["clip"] = Json::boolean(mark.clip)
  match mark.zindex {
    Some(z) => o["zindex"] = Json::number(z.to_double())
    None => ()
  }
  if !mark.aria {
    o["aria"] = Json::boolean(false)
  }
  if with_bounds {
    o["bounds"] = bounds_to_json(mark.bounds)
  }
  let items : Array[Json] = []
  for item in mark.items {
    let io : Map[String, Json] = Map([])
    for k, v in item.props {
      io[k] = value_to_json(v)
    }
    if with_bounds && !mark.marktype.is_nested() {
      io["bounds"] = bounds_to_json(item.bounds)
    }
    if mark.marktype is Group {
      io["items"] = Json::array(
        item.children.map(fn(c) { mark_to_json(c, with_bounds~) }),
      )
    }
    items.push(Json::object(io))
  }
  o["items"] = Json::array(items)
  Json::object(o)
}
