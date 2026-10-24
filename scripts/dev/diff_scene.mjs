// Compare this library's scenegraph with the official vega scenegraph.
//   node dev/diff_scene.mjs spec.vl.json [--svg] [--max N]
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';
import { runOfficial } from '../lib/official.mjs';
import { loadSpec } from '../lib/spec.mjs';

const exe = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../_build/native/debug/build/cmd/vl2svg/vl2svg.exe');

export const stripAria = (s) => s.replace(/ (role|aria-roledescription|aria-label)="[^"]*"/g, '');

export function writeSpec(spec) {
  const f = path.join(os.tmpdir(), `vl_${process.pid}_${Math.random().toString(36).slice(2)}.json`);
  fs.writeFileSync(f, JSON.stringify(spec));
  return f;
}

export function ours(file) {
  const out = execFileSync(exe, ['--scene', file], { encoding: 'utf8', maxBuffer: 1 << 28, env: { ...process.env, TZ: 'UTC' } });
  return JSON.parse(out);
}

export function diff(a, b, p, out, tol = 1e-9) {
  if (typeof a === 'number' && typeof b === 'number') {
    if (Math.abs(a - b) > tol * Math.max(1, Math.abs(a), Math.abs(b))) out.push(`${p}: ${a} != ${b}`);
    return;
  }
  if (a === null || b === null || typeof a !== 'object' || typeof b !== 'object') {
    if (a !== b) out.push(`${p}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`);
    return;
  }
  if (Array.isArray(a) !== Array.isArray(b)) { out.push(`${p}: array mismatch`); return; }
  if (Array.isArray(a)) {
    if (a.length !== b.length) out.push(`${p}: length ${a.length} != ${b.length}`);
    for (let i = 0; i < Math.min(a.length, b.length); i++) diff(a[i], b[i], `${p}[${i}]`, out, tol);
    return;
  }
  for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) {
    if (a[k] === undefined && b[k] === undefined) continue;
    if (k === 'view' || k === 'padding' || k === 'stop' || (k === 'id' && p.endsWith('.fill'))) continue;
    if ((k === 'clip' && a[k] === false && !(k in b)) || (k === 'interactive' && a[k] === true && !(k in b))) continue;
    if (!(k in a)) out.push(`${p}.${k}: missing in ours (official ${String(JSON.stringify(b[k])).slice(0, 80)})`);
    else if (!(k in b)) out.push(`${p}.${k}: extra in ours (${JSON.stringify(a[k]).slice(0, 80)})`);
    else diff(a[k], b[k], `${p}.${k}`, out, tol);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const file = path.resolve(process.argv[2]);
  const max = Number(process.argv[process.argv.indexOf('--max') + 1]) || 40;
  const spec = loadSpec(file);
  const official = await runOfficial(spec);
  const tmp = writeSpec(spec);
  const mine = ours(tmp);
  const out = [];
  diff(mine.scene, official.scene, 'scene', out);
  diff(mine.view, official.scene.view, 'view', out);
  if (process.argv.includes('--svg')) {
    const svg = execFileSync(exe, [tmp], { encoding: 'utf8', maxBuffer: 1 << 28, env: { ...process.env, TZ: 'UTC' } }).trimEnd();
    console.log(svg === stripAria(official.svg) ? 'svg identical' : `svg differs (ours ${svg.length}, official ${official.svg.length})`);
  }
  console.log(out.length ? out.slice(0, max).join('\n') + `\n${out.length} differences` : 'identical');
}
