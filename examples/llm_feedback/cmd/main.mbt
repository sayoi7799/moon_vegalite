// Feed the Vega-Lite that language models wrote to moon_vegalite:
//
//   data/*.txt  recorded model replies (no API key, no network)
//     └─ extract the JSON ─▶ render_svg ─┬─ ok     ▶ out/<name>.svg
//                                        └─ error  ▶ out/<name>.feedback.txt
//                                                    (a prompt that can be sent straight back to the model)
//
// Run from this directory:  moon run cmd

///|
/// Whether `a` sorts before `b`, comparing code units from the left. (`String::compare`
/// orders by length first with this toolchain, which would put "04_x" before "01_xyz".)
fn before(a : String, b : String) -> Bool {
  let x = a.to_array()
  let y = b.to_array()
  let n = if x.length() < y.length() { x.length() } else { y.length() }
  for i in 0..<n {
    if x[i] != y[i] {
      return x[i].to_int() < y[i].to_int()
    }
  }
  x.length() < y.length()
}

///|
/// The recorded replies, in name order (a directory listing has no fixed order).
fn reply_files() -> Array[String] raise Error {
  let names : Array[String] = []
  for name in @fs.read_dir("data") {
    if name.has_suffix(".txt") {
      let mut i = names.length()
      names.push(name)
      while i > 0 && before(name, names[i - 1]) {
        names[i] = names[i - 1]
        names[i - 1] = name
        i -= 1
      }
    }
  }
  names
}

///|
/// The SVG, or the message of the renderer (which names the JSON path).
fn try_render(spec : String) -> Result[String, String] {
  Ok(@moon_vegalite.render_svg(spec)) catch {
    e => Err(e.message())
  }
}

///|
fn run() -> Unit raise Error {
  let rendered : Array[String] = []
  let rejected : Array[String] = []
  for file in reply_files() {
    let stem = file[:file.length() - 4].to_owned()
    let reply = @fs.read_file_to_string("data/" + file)
    let spec = @feedback.extract_json(reply)
    match try_render(spec) {
      Ok(svg) => {
        @fs.write_string_to_file("out/" + stem + ".svg", svg)
        rendered.push(stem)
        println("[ok]       " + stem + "  →  out/" + stem + ".svg")
      }
      Err(message) => {
        let prompt = @feedback.repair_prompt(message)
        @fs.write_string_to_file("out/" + stem + ".feedback.txt", prompt)
        rejected.push(stem)
        println("[rejected] " + stem + "  →  out/" + stem + ".feedback.txt")
        println("           " + message)
      }
    }
  }
  println(
    rendered.length().to_string() +
    " rendered, " +
    rejected.length().to_string() +
    " sent back for correction",
  )
}

///|
fn main {
  run() catch {
    e => println("error: " + e.to_string())
  }
}
