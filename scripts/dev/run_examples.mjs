// Run a list of official examples through both pipelines and report the status of each.
//   node dev/run_examples.mjs [dir] name1 name2 ...   (default: all names listed in examples/official.txt)
import fs from 'node:fs';
import path from 'node:path';
import { runOfficial } from '../lib/official.mjs';
import { loadSpec } from '../lib/spec.mjs';
import { diff, ours, stripAria, writeSpec } from './diff_scene.mjs';
import { execFileSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const specDir = path.join(root, '.cache/vega-lite-5.23.0/examples/specs');
const names = process.argv.slice(2).length ? process.argv.slice(2) : fs.readFileSync(path.join(root, '../examples/official.txt'), 'utf8').split(/\s+/).filter(Boolean);
const exe = path.join(root, '../_build/native/debug/build/cmd/vl2svg/vl2svg.exe');
let pass = 0;
for (const n of names) {
  const file = path.join(specDir, n.endsWith('.json') ? n : n + '.vl.json');
  let status;
  try {
    const spec = loadSpec(file);
    const official = await runOfficial(spec);
    const tmp = writeSpec(spec);
    let mine;
    try { mine = ours(tmp); } catch (e) { status = 'ERR ' + String(e.stdout || e.message).split('\n')[0].slice(0, 120); }
    if (!status) {
      const out = [];
      diff(mine.scene, official.scene, 'scene', out);
      diff(mine.view, official.scene.view, 'view', out);
      const svg = execFileSync(exe, [tmp], { encoding: 'utf8', maxBuffer: 1 << 28 }).trimEnd();
      if (!out.length && svg === stripAria(official.svg)) { status = 'ok'; pass++; }
      else status = `DIFF scene=${out.length} svg=${svg === stripAria(official.svg) ? 'same' : 'differs'} ${out[0] ?? ''}`.slice(0, 200);
    }
  } catch (e) { status = 'OFFICIAL-FAIL ' + e.message.slice(0, 100); }
  console.log(n.padEnd(40), status);
}
console.log(`${pass}/${names.length} ok`);
