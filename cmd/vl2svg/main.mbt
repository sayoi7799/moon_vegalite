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
  let c = @moon_vegalite.compile(text) catch {
    e => {
      fail_with(e.message())
      return
    }
  }
  if scene_mode {
    println(@moon_vegalite.scene_json(c).stringify())
    return
  }
  let svg = @moon_vegalite.svg_of(c) catch {
    e => {
      fail_with(e.message())
      return
    }
  }
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
