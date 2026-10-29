// Fixtures for the hand-drawn mode: for a few specifications, options and seeds, the SVG that the official
// vega-lite + vega + rough.js 4.6.6 give (lib/sketch.mjs).
//   per case i:  spec_i (VL spec with inline data), svg_i (the expected hand-drawn SVG)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runOfficial } from '../lib/official.mjs';
import { loadSpec } from '../lib/spec.mjs';
import { sketchify } from '../lib/sketch.mjs';
import { asciiJson } from '../lib/mbt.mjs';
import { project } from './vlexamples.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const specDir = path.join(root, 'scripts/.cache/vega-lite-5.23.0/examples/specs');
const LIMIT = 50000;
const stripAria = (s) => s.replace(/ (role|aria-roledescription|aria-label)="[^"]*"/g, '');

const official = (n) => path.join(specDir, n + '.vl.json');
const custom = (n) => path.join(root, 'examples', n + '.vl.json');
const cases = [
  { name: 'bar', file: official('bar'), seed: 7 },
  { name: 'bar_cross_hatch_rough', file: official('bar'), seed: 3, roughness: 2, fillStyle: 'cross-hatch' },
  { name: 'bar_zigzag_seed_1', file: official('bar'), seed: 1, fillStyle: 'zigzag', hachureGap: 6, fillWeight: 2 },
  { name: 'layer_bar_line_solid', file: official('layer_bar_line'), seed: 9, fillStyle: 'solid', bowing: 0.5 },
  { name: 'layer_bar_annotations', file: official('layer_bar_annotations'), seed: 3 },
  { name: 'point_ordinal_color', file: official('point_ordinal_color'), seed: 5 },
  { name: 'custom_channel_shape_size', file: custom('channel_shape_size'), seed: 11 },
  { name: 'custom_series_area', file: custom('series_area'), seed: 5 },
  { name: 'custom_layer_independent_y', file: custom('layer_independent_y'), seed: 2, fillStyle: 'dashed' },
  { name: 'moonframe_bar_stacked', file: path.join(root, 'examples/moonframe/bar_stacked.vl.json'), seed: 12 },
];

export async function generate() {
  const constants = {};
  const entries = [];
  let i = 0;
  const literal = (kind, text) => {
    const ascii = asciiJson(text);
    const names = [];
    for (let k = 0; k * LIMIT < ascii.length || k === 0; k++) {
      const key = `${kind}_${i}_${k}`;
      constants[key] = ascii.slice(k * LIMIT, (k + 1) * LIMIT);
      names.push(key);
    }
    return names.join(' + ');
  };
  const opt = (v) => (v === undefined ? 'None' : `Some(${Number.isInteger(v) ? v.toFixed(1) : v})`);
  const dbl = (v) => (Number.isInteger(v) ? v.toFixed(1) : String(v));
  for (const c of cases) {
    const spec = project(loadSpec(c.file));
    const off = await runOfficial(spec);
    const expected = sketchify(off.scene, stripAria(off.svg), c);
    const s = literal('spec', JSON.stringify(spec));
    const svg = literal('svg', expected);
    entries.push(
      `    {\n      name: "${c.name}",\n      spec: ${s},\n      seed: ${c.seed},\n      roughness: ${dbl(c.roughness ?? 1)},\n` +
        `      bowing: ${dbl(c.bowing ?? 1)},\n      fill_style: "${c.fillStyle ?? 'hachure'}",\n      hachure_gap: ${opt(c.hachureGap)},\n` +
        `      fill_weight: ${opt(c.fillWeight)},\n      svg: ${svg},\n    },`,
    );
    i++;
  }
  const src =
    '// GENERATED FILE. DO NOT EDIT.\n// Regenerate with: cd scripts && npm ci && npm run fixtures\n\n' +
    '///|\n/// A hand-drawn rendering and what vega-lite 5.23.0 + vega 5.33.1 + rough.js 4.6.6 give for it.\npub(all) struct SketchCase {\n' +
    '  name : String\n  spec : String\n  seed : Int\n  roughness : Double\n  bowing : Double\n  fill_style : String\n' +
    '  hachure_gap : Double?\n  fill_weight : Double?\n  svg : String\n}\n\n' +
    '///|\npub fn cases() -> Array[SketchCase] {\n  [\n' + entries.join('\n') + '\n  ]\n}\n';
  return { fixtures: { sketchcases: constants }, sources: { 'fixtures/sketchcases/cases.mbt': src } };
}
