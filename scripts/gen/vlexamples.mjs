// Fixtures for the Vega-Lite compiler tests: official examples (and a few extra specs) run through vega-lite + vega.
//   per example i:  spec_i (VL spec with inline data), scene_i (vega scenegraph export), svg_i (vega SVG)
// The data of every spec is projected onto the fields the spec mentions, so fixtures stay small.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { runOfficial } from '../lib/official.mjs';
import { loadSpec } from '../lib/spec.mjs';
import { asciiJson } from '../lib/mbt.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const specDir = path.join(root, 'scripts/.cache/vega-lite-5.23.0/examples/specs');
const LIMIT = 50000;
const stripAria = (s) => s.replace(/ (role|aria-roledescription|aria-label)="[^"]*"/g, '');

/** Keep only the data fields that the spec text refers to. */
function project(spec) {
  const { values } = spec.data;
  const rest = JSON.stringify({ ...spec, data: undefined });
  const keep = [...new Set(values.flatMap((r) => Object.keys(r)))].filter((k) => rest.includes(JSON.stringify(k).slice(1, -1)));
  return { ...spec, data: { values: values.map((r) => Object.fromEntries(keep.filter((k) => k in r).map((k) => [k, r[k]]))) } };
}

function sources() {
  const names = fs.readFileSync(path.join(root, 'examples/official.txt'), 'utf8').split(/\s+/).filter(Boolean)
    .map((n) => ({ name: n, file: path.join(specDir, n + '.vl.json') }));
  const custom = fs.readdirSync(path.join(root, 'examples')).filter((f) => f.endsWith('.vl.json'))
    .map((f) => ({ name: 'custom_' + f.replace('.vl.json', ''), file: path.join(root, 'examples', f) }));
  const frame = fs.readdirSync(path.join(root, 'examples/moonframe')).filter((f) => f.endsWith('.vl.json'))
    .map((f) => ({ name: 'moonframe_' + f.replace('.vl.json', ''), file: path.join(root, 'examples/moonframe', f) }));
  return [...names, ...custom, ...frame];
}

export async function generate() {
  const constants = {};
  const entries = [];
  let i = 0;
  for (const { name, file } of sources()) {
    const spec = project(loadSpec(file));
    const official = await runOfficial(spec);
    const scene = official.scene;
    const refs = [['spec', JSON.stringify(spec)], ['scene', JSON.stringify(scene)], ['svg', stripAria(official.svg)]].map(([kind, text]) => {
      // keep every string literal below the compiler's line-length limit
      const ascii = asciiJson(text);
      const names = [];
      for (let k = 0; k * LIMIT < ascii.length || k === 0; k++) {
        const key = `${kind}_${i}_${k}`;
        constants[key] = ascii.slice(k * LIMIT, (k + 1) * LIMIT);
        names.push(key);
      }
      return names.join(' + ');
    });
    entries.push(`    ("${name}", ${refs[0]}, ${refs[1]}, ${refs[2]}),`);
    i++;
  }
  const src = '// GENERATED FILE. DO NOT EDIT.\n// Regenerate with: cd scripts && npm ci && npm run fixtures\n\n' +
    '///|\n/// (name, Vega-Lite spec, official scenegraph export, official SVG)\npub fn cases() -> Array[(String, String, String, String)] {\n  [\n' +
    entries.join('\n') + '\n  ]\n}\n';
  return { fixtures: { vlexamples: constants }, sources: { 'fixtures/vlexamples/cases.mbt': src } };
}
