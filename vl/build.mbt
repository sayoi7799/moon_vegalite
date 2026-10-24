// Small helpers for building scene items.

///|
pub suberror CompileError {
  CompileError(String)
}

///|
pub fn CompileError::message(self : CompileError) -> String {
  match self {
    CompileError(m) => m
  }
}

///|
fn num(x : Double) -> @value.Value {
  Num(x)
}

///|
fn str(s : String) -> @value.Value {
  Str(s)
}

///|
fn boolean(b : Bool) -> @value.Value {
  Bool(b)
}

///|
/// An item from (name, value) pairs.
fn mk_item(props : Array[(String, @value.Value)]) -> @scene.Item {
  let m : Map[String, @value.Value] = Map([])
  for p in props {
    m[p.0] = p.1
  }
  @scene.Item::new(props=m)
}

///|
/// JavaScript `Math.round`.
fn round(x : Double) -> Double {
  @util.js_round(x)
}

///|
fn ceil(x : Double) -> Double {
  x.ceil()
}

///|
fn max(a : Double, b : Double) -> Double {
  @util.js_max(a, b)
}

///|
fn min(a : Double, b : Double) -> Double {
  @util.js_min(a, b)
}
