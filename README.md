# moon_vegalite

[中文说明](README.zh.md)

A spec-driven [Vega-Lite](https://vega.github.io/vega-lite/) renderer written in MoonBit.
A Vega-Lite JSON specification goes in; a backend-neutral **scenegraph** and an **SVG** string come out.
It runs on the `wasm-gc`, `js` and `native` backends; the library packages use nothing but the MoonBit core library (only the
`vl2svg` tool uses `moonbitlang/x`, to read and write files).

## Quick start

A Vega-Lite specification (JSON text) in, an SVG document out
([`examples/hello`](examples/hello), a complete project you can run):

```moonbit
let spec : String =
  #|{
  #|  "data": {"values": [{"a": "A", "b": 28}, {"a": "B", "b": 55}, {"a": "C", "b": 43}]},
  #|  "mark": "bar",
  #|  "encoding": {
  #|    "x": {"field": "a", "type": "nominal"},
  #|    "y": {"field": "b", "type": "quantitative"}
  #|  }
  #|}

fn main {
  let svg = @moon_vegalite.render_svg(spec) catch {
    e => {
      println("error: " + e.message())   // names the JSON path of an unsupported feature
      return
    }
  }
  println(svg)
}
```

```sh
git clone https://github.com/sayoi7799/moon_vegalite
cd moon_vegalite/examples/hello
moon run cmd > bar.svg                     # open bar.svg in a browser
```

The same chart from the command line, with the `vl2svg` tool of this repository:

```sh
cd moon_vegalite
moon run cmd/vl2svg --target native -- examples/bar_basic.vl.json bar.svg   # SVG file (stdout without the second argument)
moon run cmd/vl2svg --target native -- --scene examples/bar_basic.vl.json   # scenegraph JSON, with the bounds of every item
```

The library API (`moon_vegalite.mbt`):

```moonbit
let svg = @moon_vegalite.render_svg(spec_json)        // SVG document
let c = @moon_vegalite.compile(spec_json)             // scenegraph + view metadata
let scene = @moon_vegalite.scene_json(c)              // the scenegraph as JSON
```

### Installation

Requirements: the [MoonBit toolchain](https://www.moonbitlang.com/download/) (developed and tested with `moon 0.1.20261016`).

The module `sayoi7799/moon_vegalite` is not on mooncakes.io yet, so it is used from a local checkout through a
`moon.work` workspace. In your own module (see [`examples/hello`](examples/hello) for the whole layout):

```
// moon.mod
import {
  "sayoi7799/moon_vegalite@0.1.0",
}
```

```
// moon.work, next to your moon.mod
members = [
  ".",
  "../moon_vegalite",   // the checkout
]
```

```
// your package's moon.pkg
import {
  "sayoi7799/moon_vegalite",
}
```

Repositories: [GitHub](https://github.com/sayoi7799/moon_vegalite) · [GitLink](https://gitlink.org.cn/sayoi7799/moon_vegalite).

## Side by side with the official output

Left: this library. Right: vega-lite 5.23.0 + vega 5.33.1. Apart from the accessibility attributes the SVG text is identical.
Open [`gallery/index.html`](gallery/index.html) directly in a browser (no server needed) for all 30 charts.

![the gallery page](docs/gallery.png)

| Chart | moon_vegalite | official vega |
| --- | --- | --- |
| `stacked_bar_v` | <img src="gallery/ours/stacked_bar_v.svg" width="320" alt="moon_vegalite: stacked_bar_v"> | <img src="gallery/official/stacked_bar_v.svg" width="320" alt="vega: stacked_bar_v"> |
| `point_color` | <img src="gallery/ours/point_color.svg" width="320" alt="moon_vegalite: point_color"> | <img src="gallery/official/point_color.svg" width="320" alt="vega: point_color"> |
| `layer_bar_line` | <img src="gallery/ours/layer_bar_line.svg" width="320" alt="moon_vegalite: layer_bar_line"> | <img src="gallery/official/layer_bar_line.svg" width="320" alt="vega: layer_bar_line"> |
| `layer_histogram` | <img src="gallery/ours/layer_histogram.svg" width="320" alt="moon_vegalite: layer_histogram"> | <img src="gallery/official/layer_histogram.svg" width="320" alt="vega: layer_histogram"> |
| `layer_color_legend_left` | <img src="gallery/ours/layer_color_legend_left.svg" width="320" alt="moon_vegalite: layer_color_legend_left"> | <img src="gallery/official/layer_color_legend_left.svg" width="320" alt="vega: layer_color_legend_left"> |
| `layer_circle_independent_color` | <img src="gallery/ours/layer_circle_independent_color.svg" width="320" alt="moon_vegalite: layer_circle_independent_color"> | <img src="gallery/official/layer_circle_independent_color.svg" width="320" alt="vega: layer_circle_independent_color"> |

## Positioning and differences from other charting libraries

* **It follows Vega-Lite, not a new grammar.** The goal is the same picture the reference implementation draws
  (vega-lite 5.23.0 + vega 5.33.1), not a similar one: axis ticks, label formats, legends, layout and mark bounds are ported
  from vega-lite / vega, including their JavaScript number and text-measurement quirks.
* **Scenegraph first.** Like Vega, the library produces a tree of marks and items with computed bounds. SVG is one renderer
  of that tree; other backends can consume it. Most MoonBit charting code draws directly; here the intermediate form is public.
* **Specifications in, pictures out.** Charts are data (JSON), so they can come from other tools. The test-suite feeds specs
  generated by [MoonFrame](https://github.com/ihb2032/MoonFrame) (`DataFrame` → Vega-Lite) to the renderer.
* **No browser, no JavaScript runtime.** Rendering is a pure function, usable in a native CLI, in WebAssembly, or in JS.
* **Honest about scope.** It is a subset renderer. Anything outside the subset fails with an error that names the JSON path
  (`encoding.color.condition 暂不支持`) instead of drawing something different.

## Support

| Area | Supported |
| --- | --- |
| Marks | `bar`, `line`, `point`, `circle`, `square`, `area`, `rule`, `tick`, `rect`, `text` |
| Channels | `x`, `y` (fields, or a numeric `datum`), `x2`, `y2` (on `rule`, `bar`, `rect`), `color` (nominal fields with the category scheme, ordinal fields with a blues ramp sampled per value, quantitative fields with a blues ramp and gradient legend, constant values), `size`, `opacity`, `shape`, `text` (size, opacity and shape on `point`, `circle`, `square`; quantitative fields give continuous scales, shape is nominal) |
| Field types | `quantitative`, `ordinal`, `nominal`, `temporal` |
| Aggregates | `count`, `sum`, `mean`, `average`, `min`, `max`, `median`, `distinct`, … (vega aggregate ops) |
| Transforms | `filter` (expression or predicate), `calculate` (expression subset), `aggregate`, `bin`, `timeUnit`, `fold`; field `bin`, `timeUnit`, `aggregate` |
| Time units | year, quarter, month, week, date, day, hours, minutes, seconds, milliseconds and combinations (UTC; "local" time is UTC) |
| Scales | `linear`, `log`, `sqrt`, `pow`, `time`, `utc`, `band`, `point`, `ordinal` (`domain`, `range`, `zero`, `nice`, `reverse`, `clamp`, `base`, `exponent`) |
| Stacking | default stacking for `bar` and `area`; `stack: zero / center / normalize / null` |
| Sorting | `sort` on discrete x / y: `ascending`, `descending`, a value list, `-x` / `-y`, `{op, field, order}` |
| Layers | position scales are shared by default (domains are merged, a band scale wins over a point scale); `resolve.scale.x / y: independent` gives each layer its own scale and axis, the second one on the opposite side; colour scales and their legend are shared, or independent with `resolve.scale.color`; layers that bin the same field identically share one bin (computed on the common data, as vega-lite hoists it) and one binned scale; marks are named `layer_0_marks`, ... |
| Guides | axes (grid, ticks, labels with flush / overlap removal, title), symbol legends, chart title |
| Layout | single view or `layer` (nested layers, inherited `data` / `transform` / `encoding`, `resolve.scale` / `legend`), `autosize: pad`, `width` / `height` as numbers or `{step}` |
| Config | accepted keys are recorded; a subset (`view`, `scale.zero`, …) is honoured |

Not supported — each raises an error that names the JSON path: `params` / `selection`, `tooltip`, `projection`,
`facet`, `concat` (`hconcat` / `vconcat`), `repeat`, `data.url` (embed `data.values` instead), `condition`, and the full
Vega expression language (only the subset used by `calculate` / `filter` is implemented). Gradient legends for
quantitative colour is limited to the default blues ramp (no `scale` options on non-positional channels).
Anything the compiler would otherwise ignore is rejected with the JSON path: unknown mark properties, `config` keys other than `scale.zero`, axis / scale / legend options that are not implemented, `sort` on other channels, and so on (`vl/validate.mbt`).

## Accuracy against the official implementation

Every expected value in the tests comes from the official packages, never from this repository:

| Layer | Reference | Where |
| --- | --- | --- |
| number formatting, ticks, `nice`, time formats, scales | d3 / vega-format / vega-scale as bundled in vega 5.33.1 | `fixtures/{numfmt,ticks,formatcases,timecases,scalecases}` |
| expressions, data transforms | vega-expression, vega-transforms | `fixtures/{exprcases,transformcases}` |
| scenegraph bounds, SVG | vega-scenegraph | `fixtures/scenecases` |
| **end to end: 78 official Vega-Lite examples (15 of them `layer_*`), edge cases, MoonFrame specs** | vega-lite 5.23.0 compile + vega scenegraph and SVG | `fixtures/vlexamples` |

For the end-to-end cases the scenegraph (every mark, item property and bounds, numbers within a relative `1e-9`) and the
SVG text (exactly, ignoring only the accessibility `role` / `aria-label` attributes) must equal the official output.
The cases cover the 78 official examples listed in `examples/official.txt`, the edge cases in `examples/edge_*.vl.json`, the channel specs in `examples/channel_*.vl.json`
(empty data, all-null column, single-value domain, log scale with non-positive values), and six charts generated by MoonFrame
(`examples/moonframe`). Invalid JSON and unsupported features are covered by `vl/errors_test.mbt`.

`moon test` passes on `wasm-gc`, `js` and `native`.

### Fixture provenance and regeneration

Fixtures are MoonBit files generated by `scripts/gen_fixtures.mjs` with the versions pinned in `scripts/package-lock.json`
(vega-lite 5.23.0, vega 5.33.1, vega-datasets 3.2.1) on Node.js 24 (some expected values depend on V8's `Math` functions, so the Node major version matters). The process time zone is fixed to UTC.

```sh
cd scripts
npm ci
npm run fixtures            # downloads the example specs of the vega-lite tag, regenerates ../fixtures
npm run gallery             # regenerates ../gallery (needs: moon build --target native cmd/vl2svg)
```

CI regenerates the fixtures and fails if any committed generated file differs.

`util/pow10_table.mbt` holds 10^k for integer k in [-330, 310]. It is generated as `Number("1e" + k)` (the correctly rounded value) and not with `Math.pow(10, k)`: V8 is not consistent about `Math.pow`, which differs by one ulp for a few exponents between Linux, macOS and Windows builds of Node 24 (and for about 70 exponents between Node 22 and 24). `js_pow10` therefore matches V8 on most builds rather than on one particular build. Compared with the Windows build that produced the previous table, only 10^23 changed, and the full test-suite, including the end-to-end comparison with the official output, passes unchanged.

`examples/moonframe/*.vl.json` were produced by `ihb2032/MoonFrame` 0.7.0 (`@chart.format_vega_lite`). MoonFrame 0.7.0 does
not currently build with the latest MoonBit toolchain (its dependencies `NyaCSV` and `quickcheck` still ship `moon.mod.json`, and
three `NyaCSV` tests use a removed `Buffer` API), so the specs were generated in a scratch project after migrating those
manifests and removing the three tests locally. The generated JSON is committed unchanged.

## Layout

| Package | Content |
| --- | --- |
| `util`, `stats`, `format`, `time`, `value` | JavaScript-compatible numbers (V8 libm), d3 ticks, d3-format, time intervals / formats, dynamic values |
| `scale` | continuous, band, point, ordinal and sequential scales, colour schemes |
| `expr`, `transform` | the expression subset, aggregate / bin / stack / timeunit / fold / filter / formula |
| `scene`, `svg` | scenegraph, mark bounds, path generation, SVG renderer |
| `spec` | strict reader of Vega-Lite JSON (unsupported features raise errors with paths) |
| `vl` | the compiler: data pipeline, scales, axes, legends, layout |
| `cmd/vl2svg` | command line tool (native) |

## Development history

Most of the work before 24 October 2026 was done locally, without committing step by step. On 24 October 2026 the
existing code was organised into commits by module (low-level numeric and time libraries, scales, expressions and
transforms, scenegraph and SVG, specification reader, compiler stages, tests, CI). The history on GitHub was rewritten
once at that time, to fold a few follow-up CI fixes into one commit. Since then every change is made on its own branch
for a GitHub issue and merged through a pull request that closes the issue.

## License

Apache-2.0. Parts of the code are ports of vega, vega-lite and d3 (BSD-3-Clause / ISC); see the file headers.
