///|
/// A Vega-Lite specification (JSON text) in, an SVG document out.
let spec : String =
  #|{
  #|  "data": {"values": [{"a": "A", "b": 28}, {"a": "B", "b": 55}, {"a": "C", "b": 43}]},
  #|  "mark": "bar",
  #|  "encoding": {
  #|    "x": {"field": "a", "type": "nominal"},
  #|    "y": {"field": "b", "type": "quantitative"}
  #|  }
  #|}

///|
fn main {
  let svg = @moon_vegalite.render_svg(spec) catch {
    e => {
      println("error: " + e.message())
      return
    }
  }
  println(svg)
}
