///|
fn collect(
  mark : @scene.Mark,
  path : String,
  out : Map[String, @scene.Bounds],
) -> Unit {
  out[path] = mark.bounds
  match mark.marktype {
    Group =>
      for i in 0..<mark.items.length() {
        let item = mark.items[i]
        let ip = if path == "" {
          i.to_string()
        } else {
          path + "/" + i.to_string()
        }
        out[ip] = item.bounds
        for j in 0..<item.children.length() {
          collect(item.children[j], ip + "." + j.to_string(), out)
        }
      }
    Line | Area => ()
    _ =>
      for i in 0..<mark.items.length() {
        let ip = if path == "" {
          i.to_string()
        } else {
          path + "/" + i.to_string()
        }
        out[ip] = mark.items[i].bounds
      }
  }
}

///|
test "mark bounds match vega-scenegraph" {
  let scenes = @util.fixture_lines(@scenecases.cases, "S")
  let bounds = @util.fixture_lines(@scenecases.cases, "B")
  assert_true(scenes.length() > 50)
  let mut compared = 0
  for s in scenes {
    let id = s[1]
    let json = @json.parse(@util.unescape_fixture(s[2])) catch {
      _ => fail("bad scene json")
    }
    let root = @scene.mark_from_json(json)
    @scene.bound_mark(root)
    let got : Map[String, @scene.Bounds] = Map([])
    collect(root, "", got)
    for b in bounds {
      if b[1] != id {
        continue
      }
      let want = b[3]
      let g = match got.get(b[2]) {
        Some(g) => g
        None => fail("\{id}: no node at path '\{b[2]}'")
      }
      if want == "-" {
        continue
      }
      let w = want
        .split(" ")
        .map(fn(h) { @util.double_from_hex(h.to_owned()) })
        .collect()
      let ok = @util.same_bits(g.x1, w[0]) &&
        @util.same_bits(g.y1, w[1]) &&
        @util.same_bits(g.x2, w[2]) &&
        @util.same_bits(g.y2, w[3])
      if !ok {
        fail(
          "\{id} path '\{b[2]}': expected [\{w[0]}, \{w[1]}, \{w[2]}, \{w[3]}], got [\{g.x1}, \{g.y1}, \{g.x2}, \{g.y2}]",
        )
      }
      compared = compared + 1
    }
  }
  assert_true(compared > 500)
}
