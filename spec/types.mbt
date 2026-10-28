// The typed Vega-Lite specification accepted by this library: a single view
// (no layer / facet / concat / repeat) with inline data.

///|
pub(all) enum Guide {
  /// property not given
  Default
  /// `null`: the guide is disabled
  Off
  /// explicit properties (an empty map for `true`)
  Props(Map[String, @value.Value])
}

///|
/// A field / value definition of an encoding channel.
pub(all) struct ChannelDef {
  field : String?
  /// "quantitative" | "ordinal" | "nominal" | "temporal"; filled by `normalize`
  mut typ : String?
  aggregate : String?
  /// `bin: true` is an empty map; None when not binned
  bin : Map[String, @value.Value]?
  /// parameters of `bin: "binned"`
  binned : Bool
  time_unit : String?
  sort : @value.Value?
  scale : Map[String, @value.Value]?
  /// `scale: null`
  scale_off : Bool
  axis : Guide
  legend : Guide
  /// `title: null` is `Some(None)`
  title : String??
  format : String?
  format_type : String?
  /// `{value: ...}` definitions
  value : @value.Value?
  datum : @value.Value?
  /// `stack: null` is Some("none")
  stack : String?
  band : Double?
  band_position : Double?
}

///|
pub(all) struct Mark {
  /// "bar" | "line" | "point" | "area" | "rule" | "tick" | "rect" | "text"
  typ : String
  /// mark properties (color, opacity, size, orient, ...), validated
  props : Map[String, @value.Value]
}

///|
/// One data transform, as written in the spec.
pub(all) enum Transform {
  Filter(FilterSpec)
  Calculate(String, String)
  Aggregate(Array[AggregateOp], Array[String])
  Bin(String, Map[String, @value.Value], Array[String])
  TimeUnit(String, String, String)
  Fold(Array[String], Array[String])
}

///|
pub(all) enum FilterSpec {
  Expr(String)
  Predicate(Predicate)
}

///|
/// A field predicate, possibly combined with and / or / not.
pub(all) enum Predicate {
  Equal(String, @value.Value, String?)
  Lt(String, @value.Value, String?)
  Lte(String, @value.Value, String?)
  Gt(String, @value.Value, String?)
  Gte(String, @value.Value, String?)
  Range(String, @value.Value, @value.Value, String?)
  OneOf(String, Array[@value.Value], String?)
  Valid(String)
  And(Array[Predicate])
  Or(Array[Predicate])
  Not(Predicate)
  Expr(String)
}

///|
pub(all) struct AggregateOp {
  op : String
  field : String?
  out : String
}

///|
/// `resolve`: for each channel, whether the layers share or keep their own
/// scale / axis / legend ("shared" or "independent").
pub(all) struct Resolve {
  scale : Map[String, String]
  axis : Map[String, String]
  legend : Map[String, String]
}

///|
/// A view: a single plot (`layer` is empty) or a layering of views. A layered
/// spec has no mark of its own (`mark.typ` is empty); `encoding`, `transform`,
/// `data` and the sizes of a layered spec are inherited by its layers.
pub(all) struct Spec {
  /// the layers of a layered view, each a unit or a nested layered view
  layer : Array[Spec]
  resolve : Resolve
  mark : Mark
  encoding : Array[(String, ChannelDef)]
  transform : Array[Transform]
  /// inline data rows; None when the spec has no data
  data : Array[Map[String, @value.Value]]?
  width : @value.Value?
  height : @value.Value?
  padding : @value.Value?
  background : String?
  title : String?
  description : String?
  config : Map[String, @value.Value]
}
