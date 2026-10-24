///|
test "SVG output matches vega's SVGStringRenderer" {
  let scenes = @util.fixture_lines(@scenecases.cases, "S")
  let opts = @util.fixture_lines(@scenecases.cases, "O")
  let svgs = @util.fixture_lines(@scenecases.cases, "V")
  assert_true(scenes.length() > 50)
  let bad : Array[String] = []
  for s in scenes {
    let id = s[1]
    let json = @json.parse(@util.unescape_fixture(s[2])) catch {
      _ => fail("bad scene json")
    }
    let root = @scene.mark_from_json(json)
    @scene.bound_mark(root)
    let o = opts.iter().find_first(fn(x) { x[1] == id }).unwrap()
    let f = o[2].split(" ").map(fn(x) { x.to_owned() }).collect()
    let w : Double = @string.from_str(f[0])
    let h : Double = @string.from_str(f[1])
    let ox : Double = @string.from_str(f[2])
    let oy : Double = @string.from_str(f[3])
    let bg : String? = if f[4] == "-" { None } else { Some(f[4]) }
    let got = @svg.render_svg(
      root,
      @svg.SvgOptions::new(w, h, origin=(ox, oy), background?=bg),
    )
    let want_line = svgs.iter().find_first(fn(x) { x[1] == id }).unwrap()
    let want = @util.unescape_fixture(want_line[2])
    if got != want {
      let mut i = 0
      while i < got.length() && i < want.length() && got[i] == want[i] {
        i = i + 1
      }
      let lo = if i > 60 { i - 60 } else { 0 }
      bad.push(
        "\{id}: first difference at \{i}\n  want: ...\{want.unsafe_substring(start=lo, end=if i + 80 < want.length() { i + 80 } else { want.length() })}\n  got:  ...\{got.unsafe_substring(start=lo, end=if i + 80 < got.length() { i + 80 } else { got.length() })}",
      )
    }
  }
  if bad.length() > 0 {
    fail(
      "\{bad.length()} of \{scenes.length()} scenes differ:\n" +
      bad[0:if bad.length() > 3 { 3 } else { bad.length() }]
      .to_owned()
      .join("\n"),
    )
  }
}
