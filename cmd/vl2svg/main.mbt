// vl2svg: render a Vega-Lite JSON file to SVG (or dump its scenegraph).
//
//   vl2svg spec.vl.json [out.svg]      write SVG (stdout when no output)
//   vl2svg --sketch [--seed N] [--roughness R] spec.vl.json [out.svg]
//                                      hand-drawn style (moon_rough); same spec and seed, same bytes
//   vl2svg --scene spec.vl.json        print the scenegraph as JSON

///|
fn fail_with(msg : String) -> Unit {
  println("error: " + msg)
  @sys.exit(1)
}

///|
fn parse_number(flag : String, text : String) -> Double {
  @string.parse_double(text) catch {
    _ => {
      fail_with(flag + " needs a number, got " + text)
      0.0
    }
  }
}

///|
/// The value after `flag`, if the flag is there.
fn flag_value(args : Array[String], flag : String) -> String? {
  for i in 0..<args.length() {
    if args[i] == flag && i + 1 < args.length() {
      return Some(args[i + 1])
    }
  }
  None
}

///|
fn run() -> Unit raise Error {
  let args = @env.args()
  let rest = args[1:].to_owned()
  let scene_mode = rest.contains("--scene")
  let sketch = rest.contains("--sketch")
  let seed = match flag_value(rest, "--seed") {
    Some(v) => parse_number("--seed", v).to_int()
    None => 1
  }
  let roughness = match flag_value(rest, "--roughness") {
    Some(v) => parse_number("--roughness", v)
    None => 1.0
  }
  // flags with a value are not file names
  let files : Array[String] = []
  let mut skip = false
  for a in rest {
    if skip {
      skip = false
    } else if a == "--seed" || a == "--roughness" {
      skip = true
    } else if a != "--scene" && a != "--sketch" {
      files.push(a)
    }
  }
  if files.length() == 0 {
    fail_with(
      "usage: vl2svg [--scene | --sketch [--seed N] [--roughness R]] spec.vl.json [out.svg]",
    )
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
  let rendered = if sketch {
    Ok(
      @moon_vegalite.svg_sketch_of(
        c,
        options=@moon_vegalite.SketchOptions::new(seed~, roughness~),
      ),
    ) catch {
      e => Err(e.message())
    }
  } else {
    Ok(@moon_vegalite.svg_of(c)) catch {
      e => Err(e.message())
    }
  }
  let svg = match rendered {
    Ok(svg) => svg
    Err(message) => {
      fail_with(message)
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
