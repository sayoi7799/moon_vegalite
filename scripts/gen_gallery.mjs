// Regenerates ../gallery: this library's SVG next to the official vega output for a set of specs.
// Needs the native CLI:  moon build --target native cmd/vl2svg
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { runOfficial } from './lib/official.mjs';
import { loadSpec } from './lib/spec.mjs';
import { writeSpec, stripAria } from './dev/diff_scene.mjs';

process.env.TZ = 'UTC';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const specDir = path.join(root, 'scripts/.cache/vega-lite-5.23.0/examples/specs');
const exe = path.join(root, '_build/native/debug/build/cmd/vl2svg/vl2svg.exe');
const items = [
  ['bar', 'Bar chart'], ['bar_aggregate', 'Aggregated horizontal bars'], ['histogram', 'Binned histogram'],
  ['stacked_bar_v', 'Stacked bars with a colour legend'], ['point_2d', 'Scatter plot'], ['point_color', 'Scatter plot with colour legend'],
  ['circle', 'Circles'], ['line', 'Time series line'], ['line_month', 'Monotone line over a time unit'], ['area', 'Area chart'],
  ['bar_month', 'Bars over a time unit'], ['tick_strip', 'Tick strip'], ['rule_extent', 'Rule ranges'], ['text_scatterplot_colored', 'Coloured text marks'],
  ['point_log', 'Log scale'],
  ['point_ordinal_color', 'Ordinal colour'], ['stacked_area_ordinal', 'Stacked area, ordinal colour'],
  ['layer_bar_line', 'Layers: bars and a line'], ['layer_histogram', 'Layers: shared bins'], ['layer_histogram_global_mean', 'Layers: histogram and a mean rule'],
  ['layer_rect_extent', 'Layers: a rect over the extent'], ['layer_bar_annotations', 'Layers: annotated bars'], ['layer_line_datum_rule', 'Layers: a datum rule'],
  ['layer_color_legend_left', 'Layers: legend on the left'], ['layer_circle_independent_color', 'Layers: independent legends'],
];
const files = items.map(([n, t]) => ({ name: n, title: t, file: path.join(specDir, n + '.vl.json') }));
for (const n of ['bar', 'bar_stacked', 'point_color', 'line', 'bar_titled']) {
  files.push({ name: 'moonframe_' + n, title: 'MoonFrame-generated: ' + n, file: path.join(root, 'examples/moonframe', n + '.vl.json') });
}
fs.mkdirSync(path.join(root, 'gallery/ours'), { recursive: true });
fs.mkdirSync(path.join(root, 'gallery/official'), { recursive: true });
let rows = '';
for (const { name, title, file } of files) {
  const spec = loadSpec(file);
  const official = await runOfficial(spec);
  const tmp = writeSpec(spec);
  const ours = execFileSync(exe, [tmp], { encoding: 'utf8', maxBuffer: 1 << 28 }).trimEnd();
  fs.writeFileSync(path.join(root, 'gallery/ours', name + '.svg'), ours + '\n');
  fs.writeFileSync(path.join(root, 'gallery/official', name + '.svg'), official.svg + '\n');
  const same = ours === stripAria(official.svg);
  rows += `<tr><td class="n"><b>${title}</b><br><code>${name}</code><br><span class="${same ? 'ok' : 'bad'}">${same ? 'identical to vega output (ignoring accessibility attributes)' : 'differs'}</span></td>` +
    `<td><img src="ours/${name}.svg" alt="moon_vegalite: ${name}"></td><td><img src="official/${name}.svg" alt="vega: ${name}"></td></tr>\n`;
}
const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>moon_vegalite gallery</title>
<style>body{font:14px system-ui,sans-serif;margin:24px;color:#222}table{border-collapse:collapse}td,th{border-top:1px solid #ddd;padding:12px;vertical-align:top;text-align:left}
.n{width:220px}.ok{color:#287d3c}.bad{color:#b3261e}img{max-width:100%}</style></head>
<body><h1>moon_vegalite gallery</h1>
<p>Left: SVG rendered by moon_vegalite. Right: the SVG produced by vega-lite 5.23.0 + vega 5.33.1 for the same specification.
Regenerate with <code>node scripts/gen_gallery.mjs</code>.</p>
<table><tr><th>Specification</th><th>moon_vegalite</th><th>vega (official)</th></tr>
${rows}</table></body></html>
`;
fs.writeFileSync(path.join(root, 'gallery/index.html'), html);
console.log(`wrote ${files.length} gallery entries`);
