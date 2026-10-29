# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `layer`: layered views with nested layers; the encoding, data and transforms of a parent are inherited by its layers (a layer with its own `data` starts from that data), the position scales are shared with merged domains, the axes are drawn once with joined titles, colours and their legend are shared.
- `resolve.scale` for `x` / `y` (independent scales, each with its own axis; the second axis of a channel goes to the opposite side) and for colour; `resolve.axis` on a shared scale is rejected.
- Lines and areas coloured by a field are drawn as one path per series.
- Mark property `opacity`, a constant `size` for `rule` and `line`, rules across the whole plot (`rule` with only `x` or only `y`).
- Text marks: `align`, `baseline`, `dx`, `dy` and `fontSize`.
- Ordinal colour fields use the blues scheme sampled once per domain value; stacked areas are imputed (zero-filled) so every series has a point at every key.
- `datum` (a number) on `x` / `y`: a constant that enters the scale domain and draws rules at that value; rule mark properties `strokeDash` and `size`.
- `x2` / `y2` on `bar` and `rect` (ranged bars; a `rect` without `x` or `y` spans the plot), `opacity` on `bar` and `rect`, constant `text`, `x` (`"width"`) and `y` (`"height"`) mark properties for `text`.
- Axis and legend titles of layers merge like vega-lite: an explicit title beats implicit ones, and an explicit `y` title stands for `y` / `y2` together.
- `bin` inside layers: layers with the same bin on a field share one bin transform and a binned scale (other layers on that scale widen and nice its domain); differing bins are rejected with their layer path. Bars binned on `y` now use the bin range like bars binned on `x`.
- Channels `size` / `opacity` / `color` / `shape` with `aggregate: count` and no field; binned fields are drawn at the middle of their bin by point marks and text, the size range of symbols follows the bin step, and `bin` on other marks is rejected. Layers that encode `size` can share one size scale with `resolve.legend.size: independent` (one legend per layer). Legends of filled bars and symbols get a transparent stroke like vega-lite's.
- Symbol legends take `legend.orient` `left` / `right`; layers that colour by stroke (lines) and by fill (filled points) share one legend that maps both channels.
- Hand-drawn style with [moon_rough](https://github.com/sayoi7799/moon_rough) 0.2.0 (rough.js 4.6.6): `render_svg_sketch` / `svg_sketch_of` with `SketchOptions` (`seed`, `roughness`, `bowing`, `fill_style`, `hachure_gap`, `fill_weight`, `fixed_decimals`) and `vl2svg --sketch --seed N --roughness R --decimals D`. Rects, rules, lines, areas, symbols and plot frames are drawn by rough, text and gradient fills are left alone; every shape has its own seed, a hash of the base seed and its position in the scenegraph, so the same specification and seed give the same bytes on every target. The output equals what vega-lite + vega + rough.js 4.6.6 give (12 fixture cases; all 30 gallery charts).
- `SvgOptions::shapes`: a caller can draw the graphic shapes itself (`Shape` with a kind, item, geometry, transform and scenegraph position); the standard output is unchanged.
- The `web` package (js) exports `render`, `render_sketch` and `version`; the demo page (`site/`, published on GitHub Pages) has an editor, the library's SVG, the official vega-embed rendering and a hand-drawn switch with a seed and a roughness slider.
- Gallery: 30 charts in three versions (this library, official vega, hand-drawn). Examples: `examples/hello`, `examples/moonframe_demo` (CSV to SVG with MoonFrame), `examples/llm_feedback` (JSON-path errors as correction prompts for a language model). `README.zh.md`.
- Benchmarks (`benchmarks/`, `moon bench`): 10,000 rows aggregated to a bar chart and a 100,000-point scatter plot on `js`, `wasm-gc` and `native`, next to vega-lite + vega on Node (`scripts/bench/`); the SVG of both scenarios is identical to the official one. Results in the README.
- Errors inside a layer carry its path (`layer[1].mark.cornerRadius 暂不支持`).
- Official `layer` examples with scenegraph and SVG comparison: `layer_bar_line`, `layer_bar_line_union`, `layer_precipitation_mean`, `layer_bar_month`, `layer_line_mean_point_raw`, `layer_single_color`, `layer_line_color_rule`, `layer_bar_labels`, `layer_line_datum_rule`, `layer_rect_extent`, `layer_bar_annotations`, `layer_histogram`, `layer_histogram_global_mean`, `layer_circle_independent_color`, `layer_color_legend_left` (15 official `layer_*` examples in all), and `line_color`; plus specs of our own in `examples/layer_*.vl.json`.

## [0.1.0] - not yet published

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
