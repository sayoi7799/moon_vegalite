// Strict reading of JSON objects. Every property must be consumed or the read
// fails: properties that Vega-Lite defines but this library does not implement
// are reported as "<path> 暂不支持", unknown ones as "<path> 未知属性".

///|
pub(all) suberror SpecError {
  SpecError(String)
}

///|
/// Message of a spec error.
pub fn SpecError::message(self : SpecError) -> String {
  match self {
    SpecError(m) => m
  }
}

///|
pub fn unsupported(path : String) -> SpecError {
  SpecError(path + " 暂不支持")
}

///|
pub fn invalid(path : String, msg : String) -> SpecError {
  SpecError(path + ": " + msg)
}

///|
pub fn join_path(base : String, key : String) -> String {
  if base == "" {
    key
  } else {
    base + "." + key
  }
}

///|
pub fn index_path(base : String, i : Int32) -> String {
  base + "[" + i.to_string() + "]"
}

///|
/// A JSON object being consumed key by key.
pub struct Reader {
  path : String
  obj : Map[String, Json]
  used : Array[String]
}

///|
pub fn Reader::new(path : String, j : Json) -> Reader raise SpecError {
  match j {
    Object(m) => { path, obj: m, used: [], }
    _ => raise invalid(path, "应为对象")
  }
}

///|
/// The raw value of a key, marking it consumed.
pub fn Reader::take(self : Reader, key : String) -> Json? {
  match self.obj.get(key) {
    Some(v) => {
      self.used.push(key)
      Some(v)
    }
    None => None
  }
}

///|
pub fn Reader::has(self : Reader, key : String) -> Bool {
  self.obj.contains(key)
}

///|
pub fn Reader::path_of(self : Reader, key : String) -> String {
  join_path(self.path, key)
}

///|
pub fn Reader::string(self : Reader, key : String) -> String? raise SpecError {
  match self.take(key) {
    None => None
    Some(String(s)) => Some(s)
    Some(_) => raise invalid(self.path_of(key), "应为字符串")
  }
}

///|
pub fn Reader::number(self : Reader, key : String) -> Double? raise SpecError {
  match self.take(key) {
    None => None
    Some(Number(x, ..)) => Some(x)
    Some(_) => raise invalid(self.path_of(key), "应为数字")
  }
}

///|
pub fn Reader::boolean(self : Reader, key : String) -> Bool? raise SpecError {
  match self.take(key) {
    None => None
    Some(True) => Some(true)
    Some(False) => Some(false)
    Some(_) => raise invalid(self.path_of(key), "应为布尔值")
  }
}

///|
/// A value of any JSON type converted to a `Value`.
pub fn Reader::value(self : Reader, key : String) -> @value.Value? {
  match self.take(key) {
    None => None
    Some(j) => Some(@value.from_json(j))
  }
}

///|
/// Fail on any property that has not been consumed. Names in `unsupported_keys`
/// are valid Vega-Lite properties that this library does not implement.
pub fn Reader::finish(
  self : Reader,
  unsupported_keys~ : Array[String] = [],
) -> Unit raise SpecError {
  for k, _ in self.obj {
    if !self.used.contains(k) {
      if unsupported_keys.contains(k) {
        raise unsupported(self.path_of(k))
      } else {
        raise SpecError(self.path_of(k) + " 未知属性")
      }
    }
  }
}

///|
/// Accept (and ignore) properties that do not affect rendering.
pub fn Reader::ignore(self : Reader, keys : Array[String]) -> Unit {
  for k in keys {
    if self.obj.contains(k) {
      self.used.push(k)
    }
  }
}
