// The entry point of the demo page (`site/`): built for the js target as an ES
// module that exports `render` and `version`.
//
//   import { render } from "./web.js";
//   const out = render(specText);   // SVG text, or "ERROR: " + message

///|
/// Render a Vega-Lite specification (JSON text). The result is the SVG
/// document, or `"ERROR: "` followed by the message, which names the JSON path
/// of whatever is not supported (`encoding.color.condition 暂不支持`).
pub fn render(spec : String) -> String {
  @moon_vegalite.render_svg(spec) catch {
    e => "ERROR: " + e.message()
  }
}

///|
/// The library version.
pub fn version() -> String {
  @moon_vegalite.version()
}
