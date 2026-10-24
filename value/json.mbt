// Conversion from parsed JSON to dynamic cell values.

///|
/// Convert JSON to a `Value`: objects keep their key order, numbers become
/// doubles, `true` / `false` / `null` map to the matching variants.
pub fn from_json(j : Json) -> Value {
  match j {
    Null => Null
    True => Bool(true)
    False => Bool(false)
    Number(x, ..) => Num(x)
    String(s) => Str(s)
    Array(items) => Arr(items.map(from_json))
    Object(m) => {
      let out : Map[String, Value] = Map([])
      for k, v in m {
        out[k] = from_json(v)
      }
      Obj(out)
    }
  }
}
