// The same benchmarks as bench/bench_test.mbt, for the official pipeline on Node: vega-lite 5.23.0 + vega 5.33.1.
//   node scripts/bench/vega_bench.mjs            time both scenarios
//   node scripts/bench/vega_bench.mjs --check    also compare the SVG with moon_vegalite's (needs: moon build --target native cmd/vl2svg)
//
// Each iteration starts from the specification TEXT, like render_svg does:
//   "to SVG":        JSON.parse -> vega-lite compile -> vega parse + View.runAsync -> view.toSVG()
//   "to scenegraph": the same without toSVG()
// The first iterations warm up the JIT and are not measured; the measured ones are reported as mean ± σ, min … max.
import * as vl from 'vega-lite';
import * as vega from 'vega';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { SCENARIOS, checksum } from './specs.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const check = process.argv.includes('--check');
const SAMPLES = 10;

async function pipeline(text, toSvg) {
  const spec = JSON.parse(text);
  const compiled = vl.compile(spec).spec;
  const view = new vega.View(vega.parse(compiled), { renderer: 'none', logLevel: 0 });
  await view.runAsync();
  const out = toSvg ? await view.toSVG() : view.scenegraph().root.items.length;
  view.finalize();
  return out;
}

const fmt = (ms) => (ms >= 1000 ? `${(ms / 1000).toFixed(2)} s` : ms >= 1 ? `${ms.toFixed(2)} ms` : `${(ms * 1000).toFixed(2)} µs`);

async function measure(text, toSvg) {
  // iterations per sample: enough to last at least ~100 ms (like moon bench's batches)
  let t0 = performance.now();
  await pipeline(text, toSvg);
  const first = performance.now() - t0;
  const batch = Math.max(1, Math.ceil(100 / first));
  for (let i = 0; i < 3; i++) await pipeline(text, toSvg); // warm-up
  const samples = [];
  for (let s = 0; s < SAMPLES; s++) {
    t0 = performance.now();
    for (let i = 0; i < batch; i++) await pipeline(text, toSvg);
    samples.push((performance.now() - t0) / batch);
  }
  const mean = samples.reduce((a, b) => a + b, 0) / samples.length;
  const sd = Math.sqrt(samples.reduce((a, b) => a + (b - mean) ** 2, 0) / (samples.length - 1));
  return { mean, sd, min: Math.min(...samples), max: Math.max(...samples), batch };
}

console.log(`node ${process.version}, vega-lite ${vl.version}, vega ${vega.version}`);
console.log(`${os.cpus()[0].model.trim()} (${os.cpus().length} threads), ${os.type()} ${os.release()}`);
for (const [name, { title, spec }] of Object.entries(SCENARIOS)) {
  const text = spec();
  console.log(`\n${name}: ${title} (${(text.length / 1024).toFixed(0)} KB of JSON, checksum ${checksum(text)})`);
  for (const [label, toSvg] of [['to SVG', true], ['to scenegraph', false]]) {
    const r = await measure(text, toSvg);
    console.log(`  ${label.padEnd(14)} ${fmt(r.mean)} ± ${fmt(r.sd)}   ${fmt(r.min)} … ${fmt(r.max)}   in ${SAMPLES} × ${r.batch} runs`);
  }
  if (check) {
    const official = await pipeline(text, true);
    const file = path.join(os.tmpdir(), `bench_${name}.json`);
    fs.writeFileSync(file, text);
    const exe = path.join(root, '_build/native/debug/build/cmd/vl2svg/vl2svg.exe');
    const ours = execFileSync(exe, [file], { encoding: 'utf8', maxBuffer: 1 << 30 }).trimEnd();
    const strip = (s) => s.replace(/ (role|aria-roledescription|aria-label)="[^"]*"/g, '');
    const same = ours === strip(official);
    console.log(`  SVG ${(ours.length / 1024 / 1024).toFixed(1)} MB: ${same ? 'identical to moon_vegalite' : 'DIFFERS from moon_vegalite'}`);
    if (!same) process.exitCode = 1;
  }
}
