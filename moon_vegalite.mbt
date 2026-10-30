// Public API: compile a Vega-Lite specification to a scenegraph and render
// it as SVG.
//
//   let svg = @moon_vegalite.render_svg(spec_json)
//   let scene = @moon_vegalite.compile(spec_json)   // backend-neutral scenegraph

///|
/// Library version, kept in sync with `moon.mod`.
pub fn version() -> String {
  "0.2.0"
}

///|
/// The result of compiling a specification: see `@vl.Compiled`.
pub using @vl {type Compiled}

///|
/// An error raised for malformed JSON, unsupported Vega-Lite features
/// (the message names the JSON path) or rendering failures.
pub suberror RenderError {
  RenderError(String)
}

///|
pub fn RenderError::message(self : RenderError) -> String {
  match self {
    RenderError(m) => m
  }
}

///|
/// Compile a Vega-Lite specification (JSON text) into a scenegraph.
pub fn compile(spec : String) -> Compiled raise RenderError {
  @vl.compile(spec) catch {
    e => raise RenderError(e.message())
  }
}

///|
/// Render a Vega-Lite specification (JSON text) as an SVG document.
/// `scale` multiplies the pixel size of the image (the `viewBox` is kept).
pub fn render_svg(
  spec : String,
  scale~ : Double = 1.0,
) -> String raise RenderError {
  svg_of(compile(spec), scale~)
}

///|
/// Render an already compiled specification as SVG.
pub fn svg_of(c : Compiled, scale~ : Double = 1.0) -> String raise RenderError {
  svg_with(c, scale, None)
}

///|
fn svg_with(
  c : Compiled,
  scale : Double,
  shapes : ((@svg.Shape) -> String?)?,
) -> String raise RenderError {
  @svg.render_svg(
    c.scene,
    @svg.SvgOptions::new(
      c.view_width + 2.0 * c.padding,
      c.view_height + 2.0 * c.padding,
      origin=(c.origin.0 + c.padding, c.origin.1 + c.padding),
      background?=c.background,
      scale~,
      shapes?,
    ),
  ) catch {
    @scene.SceneError(m) => raise RenderError(m)
  }
}

///|
/// The options of the hand-drawn style: the seed, `roughness`, `bowing` and `fill_style`.
pub using @sketch {type SketchOptions, type FillStyle}

///|
/// Render a Vega-Lite specification (JSON text) as a hand-drawn SVG document: the
/// rectangles, lines, paths and symbols are drawn by moon_rough (rough.js), the text is
/// left as it is. The same specification and `options.seed` always give the same bytes.
pub fn render_svg_sketch(
  spec : String,
  options~ : SketchOptions = SketchOptions::new(),
  scale~ : Double = 1.0,
) -> String raise RenderError {
  svg_sketch_of(compile(spec), options~, scale~)
}

///|
/// Render an already compiled specification as a hand-drawn SVG.
pub fn svg_sketch_of(
  c : Compiled,
  options~ : SketchOptions = SketchOptions::new(),
  scale~ : Double = 1.0,
) -> String raise RenderError {
  svg_with(c, scale, Some(@sketch.shape_drawer(options)))
}

///|
/// The scenegraph of a compiled specification as JSON: a `view` object (size,
/// origin, background) and the `scene` tree with the bounds of every mark and
/// item. This is the format the test-suite compares with vega's scenegraph.
pub fn scene_json(c : Compiled) -> Json {
  {
    "view": {
      "width": c.width,
      "height": c.height,
      "origin": [c.origin.0, c.origin.1],
      "padding": c.padding,
      "background": match c.background {
        Some(b) => b
        None => Json::null()
      },
    },
    "scene": @scene.mark_to_json(c.scene, with_bounds=true),
  }
}
