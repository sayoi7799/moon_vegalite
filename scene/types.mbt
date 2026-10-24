// The backend-neutral scenegraph: a tree of marks, each holding items whose
// properties mirror vega-scenegraph (x, y, width, fill, stroke, text, ...).
// Group items contain further marks.

///|
pub(all) enum MarkType {
  Group
  Rect
  Rule
  Text
  Symbol
  Line
  Area
}

///|
pub fn MarkType::name(self : MarkType) -> String {
  match self {
    Group => "group"
    Rect => "rect"
    Rule => "rule"
    Text => "text"
    Symbol => "symbol"
    Line => "line"
    Area => "area"
  }
}

///|
pub fn MarkType::from_name(name : String) -> MarkType? {
  match name {
    "group" => Some(Group)
    "rect" => Some(Rect)
    "rule" => Some(Rule)
    "text" => Some(Text)
    "symbol" => Some(Symbol)
    "line" => Some(Line)
    "area" => Some(Area)
    _ => None
  }
}

///|
/// Line and area marks render all their items as one path.
pub fn MarkType::is_nested(self : MarkType) -> Bool {
  self is Line || self is Area
}

///|
pub(all) struct Item {
  /// scene properties by name (`x`, `y`, `fill`, `fontSize`, ...)
  props : Map[String, @value.Value]
  bounds : Bounds
  /// child marks (group items only)
  children : Array[Mark]
}

///|
pub(all) struct Mark {
  marktype : MarkType
  name : String?
  role : String?
  interactive : Bool
  clip : Bool
  zindex : Int32?
  /// false hides the mark from assistive technology (`aria-hidden`)
  aria : Bool
  items : Array[Item]
  bounds : Bounds
}

///|
pub fn Item::new(props~ : Map[String, @value.Value] = Map([])) -> Item {
  { props, bounds: Bounds::new(), children: [], }
}

///|
pub fn Mark::new(
  marktype : MarkType,
  name? : String,
  role? : String,
  interactive~ : Bool = true,
  clip~ : Bool = false,
  zindex? : Int32,
  aria~ : Bool = true,
  items~ : Array[Item] = [],
) -> Mark {
  {
    marktype,
    name,
    role,
    interactive,
    clip,
    zindex,
    aria,
    items,
    bounds: Bounds::new(),
  }
}

// ---- property access with JavaScript semantics ----

///|
pub fn Item::get(self : Item, key : String) -> @value.Value {
  match self.props.get(key) {
    Some(v) => v
    None => Undef
  }
}

///|
pub fn Item::set(self : Item, key : String, v : @value.Value) -> Unit {
  self.props[key] = v
}

///|
pub fn Item::set_num(self : Item, key : String, x : Double) -> Unit {
  self.props[key] = Num(x)
}

///|
pub fn Item::set_str(self : Item, key : String, s : String) -> Unit {
  self.props[key] = Str(s)
}

///|
/// `item[key] || 0`
pub fn Item::num0(self : Item, key : String) -> Double {
  let v = self.get(key)
  if v.truthy() {
    v.to_number()
  } else {
    0.0
  }
}

///|
/// `item[key] != null ? +item[key] : default`
pub fn Item::num_or(self : Item, key : String, default : Double) -> Double {
  match self.get(key) {
    Null | Undef => default
    v => v.to_number()
  }
}

///|
/// The value when present and not null, as a number.
pub fn Item::opt_num(self : Item, key : String) -> Double? {
  match self.get(key) {
    Null | Undef => None
    v => Some(v.to_number())
  }
}

///|
/// A string property, None when missing or null.
pub fn Item::str(self : Item, key : String) -> String? {
  match self.get(key) {
    Null | Undef => None
    Str(s) => Some(s)
    v => Some(v.to_js_string())
  }
}

///|
/// JavaScript truthiness of a property.
pub fn Item::truthy(self : Item, key : String) -> Bool {
  self.get(key).truthy()
}

///|
pub fn Item::has(self : Item, key : String) -> Bool {
  match self.get(key) {
    Null | Undef => false
    _ => true
  }
}
