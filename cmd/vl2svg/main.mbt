// vl2svg: render a Vega-Lite JSON file to SVG (or dump its scenegraph).
//
//   vl2svg spec.vl.json [out.svg]      write SVG (stdout when no output)
//   vl2svg --scene spec.vl.json        print the scenegraph as JSON

///|
fn fail_with(msg : String) -> Unit {
  println("error: " + msg)
  @sys.exit(1)
}

///|
fn run() -> Unit raise Error {
  let args = @env.args()
  let rest = args[1:].to_owned()
  let scene_mode = rest.contains("--scene")
  let files = rest.filter(fn(a) { a != "--scene" })
  if files.length() == 0 {
    fail_with("usage: vl2svg [--scene] spec.vl.json [out.svg]")
    return
  }
  let text = @fs.read_file_to_string(files[0])
  let c = @vl.compile(text) catch {
    e => {
      fail_with(e.message())
      return
    }
  }
  if scene_mode {
    let j : Json = {
      "view": {
        "width": c.width,
        "height": c.height,
        "origin": [c.origin.0, c.origin.1],
        "background": match c.background {
          Some(b) => b
          None => Json::null()
        },
      },
      "scene": @scene.mark_to_json(c.scene, with_bounds=true),
    }
    println(j.stringify())
    return
  }
  let svg = @svg.render_svg(
    c.scene,
    @svg.SvgOptions::new(
      c.view_width + 2.0 * c.padding,
      c.view_height + 2.0 * c.padding,
      origin=(c.origin.0 + c.padding, c.origin.1 + c.padding),
      background?=c.background,
    ),
  )
  if files.length() > 1 {
    @fs.write_string_to_file(files[1], svg)
  } else {
    println(svg)
  }
}

///|
fn main {
  run() catch {
    e => fail_with(e.to_string())
  }
}
