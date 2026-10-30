# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-10-30

The first version meant for publication. Layered views, pie and donut charts, a hand-drawn style, an online demo and
a good deal more of the official examples; the official comparison now covers 80 examples (60 before), of which
15 are `layer_*` and 2 are `arc_*`.

### Added

Layers and composition

- `layer`: layered views with nested layers; the encoding, data and transforms of a parent are inherited by its layers (a layer with its own `data` starts from that data), the position scales are shared with merged domains, the axes are drawn once, colours and their legend are shared. Errors inside a layer carry its path (`layer[1].mark.cornerRadius 暂不支持`).
- `resolve.scale` for `x` / `y` (independent scales, each with its own axis; the second axis of a channel goes to the opposite side) and for colour; `resolve.legend.size: independent` gives each layer its own legend of one shared size scale; `resolve.axis` on a shared scale is rejected.
- Axis and legend titles of layers merge like vega-lite: an explicit title beats implicit ones, and an explicit `y` title stands for `y` / `y2` together; layers that colour by stroke (lines) and by fill (filled points) share one legend that maps both.
- `bin` inside layers: layers with the same bin on a field share one bin transform (computed on the common data, as vega-lite hoists it) and a binned scale; other layers on that scale widen and nice its domain; differing bins are rejected with their layer path.
- Lines and areas coloured by a field are drawn as one path per series; stacked areas are imputed (zero-filled) so every series has a point at every key.

Marks, channels and properties

- `mark: arc` (pie and donut charts): the `theta` channel (stacked around the circle as `zero` or `normalize`, `scale.range`), `color`, and the mark properties `innerRadius`, `outerRadius`, `padAngle`, `cornerRadius`, `stroke`, `strokeWidth`. The arc path is a port of d3-shape's `arc`; bounds and SVG come out like vega-scenegraph's. A view without an x or y channel has no frame stroke, as in vega-lite. `radius`, `theta2`, `tooltip` and theta bins fail with their path.
- `datum` (a number) on `x` / `y`: a constant that enters the scale domain and draws rules at that value; rule properties `strokeDash` and `size`.
- `x2` / `y2` on `bar` and `rect` (ranged bars; a `rect` without `x` or `y` spans the plot), rules across the whole plot, `opacity` on `bar`, `rect` and `arc`.
- Text marks: `align`, `baseline`, `dx`, `dy`, `fontSize`, a constant `text`, and `x` (`"width"`) / `y` (`"height"`) for a text at the edge of the plot.
- Ordinal colour fields use the blues scheme sampled once per domain value.
- `size`, `opacity`, `color` and `shape` with `aggregate: count` and no field; binned fields are drawn at the middle of their bin by point marks and text, and the size range of symbols follows the bin step.
- `legend.orient` `left` / `right` on symbol legends; the legends of filled bars and symbols get a transparent stroke, and the stroke of an arc, like vega-lite's.

Hand-drawn style

- [moon_rough](https://github.com/sayoi7799/moon_rough) 0.2.0 (rough.js 4.6.6) draws the shapes: `render_svg_sketch` / `svg_sketch_of` with `SketchOptions` (`seed`, `roughness`, `bowing`, `fill_style`, `hachure_gap`, `fill_weight`, `fixed_decimals`) and `vl2svg --sketch --seed N --roughness R --decimals D`. Rects, rules, lines, areas, symbols, arcs and plot frames are drawn by rough, text and gradient fills are left alone. Every shape has its own seed, a hash of the base seed and its position in the scenegraph, so the same specification and seed give the same bytes on every target.
- `SvgOptions::shapes`: a caller can draw the graphic shapes itself (`Shape` with a kind, item, geometry, transform and scenegraph position); the standard output is unchanged.
- `util`: `v8_sin`, `v8_cos`, `v8_asin`, `v8_acos`, `v8_atan`, `v8_atan2`, bit-identical to V8's `Math`, used by the arc path and the path bounds.

Web, examples and documentation

- The `web` package (js) exports `render`, `render_sketch` and `version`; the demo page (`site/`, published on GitHub Pages) has an editor, the library's SVG, the official vega-embed rendering with an identical-or-not badge, and a hand-drawn switch with a seed and a roughness slider.
- Examples: `examples/hello` (the quick start), `examples/moonframe_demo` (CSV to SVG with MoonFrame), `examples/llm_feedback` (JSON-path errors as correction prompts for a language model, with recorded replies).
- Gallery with 32 charts, each in three versions (this library, the official vega output, hand-drawn).
- Benchmarks (`benchmarks/`, `moon bench`): 10,000 rows aggregated to a bar chart and a 100,000-point scatter plot on `js`, `wasm-gc` and `native`, next to vega-lite + vega on Node (`scripts/bench/`); the SVG of both scenarios is identical to the official one.
- `README.zh.md`, a rewritten Support table, `docs/defense.md`, `THIRD_PARTY_LICENSES`.

Tests and tooling

- Official comparison for 80 examples: 15 `layer_*` (`layer_bar_line`, `layer_bar_line_union`, `layer_precipitation_mean`, `layer_bar_month`, `layer_line_mean_point_raw`, `layer_single_color`, `layer_line_color_rule`, `layer_bar_labels`, `layer_line_datum_rule`, `layer_rect_extent`, `layer_bar_annotations`, `layer_histogram`, `layer_histogram_global_mean`, `layer_circle_independent_color`, `layer_color_legend_left`), `arc_pie`, `arc_donut`, `point_ordinal_color`, `stacked_area_ordinal`, and specs of our own in `examples/`.
- The hand-drawn output is compared byte for byte with vega-lite + vega + rough.js 4.6.6 (`scripts/lib/sketch.mjs`, `fixtures/sketchcases`, 16 cases; all 32 gallery charts); the V8 maths functions and 40 random arc scenes are compared with Node and vega-scenegraph.
- CI also runs the README examples and the LLM feedback example, builds and smoke-tests the demo page, publishes it to GitHub Pages from `main`, and checks that the example specifications of the page are current.

### Changed

- The module depends on `sayoi7799/moon_rough@0.2.0`, used only by the `sketch` package; `roughjs` 4.6.6 joins the scripts that generate fixtures.
- Public API additions: `render_svg_sketch`, `svg_sketch_of`, `SketchOptions`, `FillStyle`, `SvgOptions::shapes`, `Shape`, `ShapeKind`, `Geometry`, the `Arc` mark type of `@scene`.
- Path arcs and the bounds of arcs use V8-exact sine and cosine instead of the platform's for angles that are not whole degrees.

### Fixed

- `size`, `color`, `opacity` and `shape` with `aggregate: count` and no field were silently dropped; bars binned on `y` ignored the bin range; `bin` on marks that cannot draw it was ignored and is now rejected.

### Notes

- Not supported (each fails with its path): interaction (`params`, `selection`, `tooltip`, `condition`), `projection`, `facet`, `concat`, `repeat`, `autosize`, `data.url`, `radius` and polar text, `window`, `joinaggregate` and the other transforms not listed in the README, the full Vega expression language, non-default colour scales and legend options. See the Support table of the README.
- Fixtures must be generated with `TZ=UTC` on Node 24; see the README.

## [0.1.0] - internal, never published

First version: a Vega-Lite specification goes in, a scenegraph and an SVG document come out.

### Added

- Public API in the root package: `compile`, `render_svg`, `svg_of`, `scene_json`, `RenderError`.
- Command line tool `cmd/vl2svg` (native): SVG output and `--scene` for the scenegraph as JSON.
- Marks: `bar`, `line`, `point`, `circle`, `square`, `area`, `rule`, `tick`, `rect`, `text`.
- Channels: `x`, `y`, `x2`, `y2`, `color`, `size`, `opacity`, `shape`, `text`.
  `size`, `opacity` and `shape` apply to `point`, `circle` and `square`; `x2` and `y2` to `rule`; `text` to `text`.
- Field types `quantitative`, `ordinal`, `nominal`, `temporal`.
- Encoding-level `aggregate` (`count`, `sum`, `mean`, `min`, `max`, `median`, …), `bin`, `timeUnit`, `sort`
  (`ascending`, `descending`, value list, `-x` / `-y`, `{op, field, order}`), and `stack`
  (`zero`, `center`, `normalize`, `null`); bars and areas stack by default.
- Transforms `filter` (expression or predicate), `calculate` (expression subset), `aggregate`, `bin`,
  `timeUnit`, `fold`.
- Scales: `linear`, `log`, `sqrt`, `pow`, `time`, `utc`, `band`, `point`, `ordinal`; the scale properties
  `type`, `domain`, `domainMin`, `domainMax`, `zero`, `nice`, `reverse`, `clamp`, `base`, `exponent`, `range`.
- Guides: axes (grid, ticks, labels with flush and overlap removal, title; `axis: null`), symbol legends,
  vertical gradient legends for quantitative colour, chart title.
- `autosize: pad` layout with `width` / `height` as numbers or `{step}`; `config.scale.zero`.
- Unsupported features and properties that are not implemented fail with an error that names the JSON path
  (for example `encoding.color.condition 暂不支持`) instead of being ignored.
- Tests whose expected values come from vega-lite 5.23.0 and vega 5.33.1 (pinned in `scripts/package-lock.json`):
  60 official examples, edge cases (empty data, all-null column, single-value domain, log scale with
  non-positive values), channel and stack specs, and specs generated by MoonFrame. Scenegraphs are compared
  with a relative tolerance of 1e-9, SVG text exactly.
- Fixture generators in `scripts/`, and a gallery that places the SVG from this library next to the official one.
- GitHub Actions: format, check with `--deny-warn`, tests on wasm-gc, js and native on Linux, macOS and Windows,
  a build of all targets, a check that the generated interface files are up to date, and a check that the
  committed fixtures equal what the official packages produce.

### Notes

- `util/pow10_table.mbt` holds the correctly rounded 10^k. V8's `Math.pow(10, k)` differs by one ulp for a few
  exponents between platforms and Node versions, so it is not used to generate the table.
- "Local" time is treated as UTC.
- Not supported: `params` / `selection`, `tooltip`, `projection`, `layer`, `facet`, `concat`, `repeat`,
  `data.url`, `condition`, the full Vega expression language, non-default colour scales and legend options.
