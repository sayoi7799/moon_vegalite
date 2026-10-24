// Fixtures for scale/: continuous, band/point, ordinal and sequential scales built with vega.scale(),
// and the palette data of vega-scale (generated into scale/palettes.mbt).
import fs from 'node:fs';
import { createRequire } from 'node:module';
import vm from 'node:vm';
import * as vega from 'vega';
import { escLine } from '../lib/mbt.mjs';
import { hex16 } from '../lib/prng.mjs';

const require = createRequire(import.meta.url);

const hx = (list) => list.map((x) => (x === undefined ? 'u' : hex16(x))).join(' ');
const names = (list) => list.map((x) => escLine(String(x))).join(' ');

/** Read vega-scale's palette tables (palettes.js) as plain data. */
function loadPalettes() {
  const src = fs.readFileSync(require.resolve('vega-scale/package.json').replace('package.json', 'src/palettes.js'), 'utf8');
  const chromatic = require('d3-scale-chromatic');
  const body = src
    .replace(/import \{[^}]*\} from 'd3-scale-chromatic';/, '')
    .replace(/export const /g, 'var ');
  const ctx = { ...chromatic };
  vm.createContext(ctx);
  vm.runInContext(body, ctx);
  return { continuous: ctx.continuous, discrete: ctx.discrete };
}

function splitHex(palette) {
  if (Array.isArray(palette)) return palette.map((c) => c.toLowerCase());
  const out = [];
  for (let i = 0; i + 6 <= palette.length; i += 6) out.push('#' + palette.slice(i, i + 6));
  return out;
}

export function generate() {
  const lines = [];

  // --- palettes ---
  const { continuous, discrete } = loadPalettes();
  let src =
    '// GENERATED FILE. DO NOT EDIT.\n' +
    '// Regenerate with: cd scripts && npm ci && npm run fixtures\n' +
    '// Colour tables of vega-scale 7.4.3 (BSD-3-Clause) and d3-scale-chromatic (ISC/Apache-2.0), see README.\n\n';
  const arr = (name, table) => {
    let s = `///|\nfn ${name}(name : String) -> Array[String]? {\n  match name {\n`;
    for (const [k, v] of Object.entries(table)) {
      const colors = splitHex(v);
      s += `    "${k.toLowerCase()}" =>\n      Some([${colors.map((c) => `"${c}"`).join(', ')}])\n`;
    }
    return s + '    _ => None\n  }\n}\n\n';
  };
  src += arr('discrete_palette', discrete) + arr('continuous_palette', continuous);

  // --- continuous scales ---
  const domains = [
    [0, 100], [0, 1], [-5, 5], [100, 0], [1, 1000], [0.001, 100], [3, 3], [0.5, 12.5], [-1000, 1000000], [2, 9], [-100, -1], [1e-6, 1e6],
    [0, 55], [0.013, 0.87], [-0.37, 0.52], [1, 7.5], [10.5, 99.5], [0, 0.0003], [1e9, 5e9], [12, 12.0001],
  ];
  const ranges = [[0, 200], [200, 0], [10, 50], [0, 1], [-1, 1], [5, 5]];
  const xs = [-10, 0, 0.001, 0.5, 1, 3, 7, 12.5, 50, 100, 150, 1e6, -0.5, 4.35];
  const kinds = [
    ['linear', 0], ['sqrt', 0], ['pow', 2], ['pow', 0.3], ['log', 10], ['log', 2], ['log', Math.E], ['log', 5],
  ];
  let n = 0;
  for (const [kind, param] of kinds) {
    for (const d of domains) {
      if (kind === 'log' && (d[0] <= 0 && d[1] >= 0)) continue;
      for (const r of [ranges[n++ % ranges.length]]) {
        for (const [clamp, round, nice] of [[false, false, '-'], [true, false, '-'], [false, true, '-'], [false, false, 5], [false, false, 10]]) {
          {
            {
              const s = vega.scale(kind)();
              if (kind === 'pow') s.exponent(param);
              if (kind === 'log') s.base(param);
              s.domain(d).clamp(clamp);
              if (round) s.rangeRound(r); else s.range(r);
              if (nice !== '-') s.nice(nice);
              const dom = s.domain();
              const ys = xs.map((x) => s(x));
              const ticks = [2, 5, 10].map((c) => hx(s.ticks(c)) || '-').join(';');
              lines.push(`cont|${kind},${hex16(param)}|${hx(d)}|${hx(r)}|${clamp ? 1 : 0},${round ? 1 : 0},${nice}|${hx(xs)}|${hx(ys)}|${hx(dom)}|${ticks}`);
            }
          }
        }
      }
    }
  }
  // three-point domains (piecewise)
  for (const [d, r] of [[[0, 50, 100], [0, 10, 200]], [[100, 50, 0], [0, 10, 200]], [[-10, 0, 10], [1, 2, 4]]]) {
    const s = vega.scale('linear')().domain(d).range(r);
    lines.push(`cont|linear,${hex16(0)}|${hx(d)}|${hx(r)}|0,0,-|${hx(xs)}|${hx(xs.map((x) => s(x)))}|${hx(s.domain())}|${[2, 5, 10].map((c) => hx(s.ticks(c))).join(';')}`);
  }

  // --- band & point ---
  const rng = [[0, 200], [200, 0], [0, 1], [10, 90], [0, 333]];
  for (const type of ['band', 'point']) {
    for (const count of [0, 1, 2, 3, 5, 8]) {
      const domain = Array.from({ length: count }, (_, i) => `v${i}`);
      for (const r of rng) {
        for (const [pi, po, align] of [[0, 0, 0.5], [0.1, 0.05, 0.5], [0.2, 0.2, 0], [0.5, 0.1, 1], [1, 0.5, 0.5], [0, 0.3, 0.25]]) {
          for (const round of [false, true]) {
            const s = vega.scale(type)();
            s.domain(domain);
            if (type === 'band') s.paddingInner(pi); // point has fixed inner padding
            s.paddingOuter(po).align(align);
            if (round) s.rangeRound(r); else s.range(r);
            const pos = domain.map((v) => s(v));
            lines.push(`band|${type}|${count}|${hx(r)}|${hex16(pi)},${hex16(po)},${hex16(align)},${round ? 1 : 0}|${hex16(s.bandwidth())},${hex16(s.step())}|${hx(pos)}`);
          }
        }
      }
    }
  }

  // --- ordinal ---
  const ordinalCases = [
    [['a', 'b', 'c'], ['red', 'green', 'blue']],
    [['a', 'b', 'c', 'd', 'e'], ['x', 'y']],
    [['a'], ['x', 'y', 'z']],
    [[], ['x']],
  ];
  for (const [d, r] of ordinalCases) {
    const s = vega.scale('ordinal')().domain(d).range(r).unknown(undefined);
    s.unknown(undefined);
    const probe = [...d, 'zzz'];
    lines.push(`ordinal|${names(d) || '-'}|${names(r)}|${names(probe)}|${probe.map((p) => { const v = s(p); return v === undefined ? 'u' : escLine(String(v)); }).join(' ')}`);
  }

  // --- sequential colour schemes ---
  const ts = [0, 0.05, 0.1, 0.25, 1 / 3, 0.4, 0.5, 0.6, 2 / 3, 0.75, 0.9, 0.95, 1];
  for (const name of ['blues', 'viridis', 'yellowgreenblue', 'blueorange', 'reds', 'magma', 'spectral', 'greys', 'redyellowblue', 'purpleorange']) {
    const interp = vega.scheme(name);
    lines.push(`scheme|${name}|${hx(ts)}|${ts.map((t) => interp(t)).join(' ')}`);
  }
  // sequential scale: domain mapping with clamp
  for (const [d, name, clamp] of [[[0, 100], 'blues', false], [[10, 20], 'yellowgreenblue', true], [[100, 0], 'viridis', false], [[5, 5], 'blues', false]]) {
    const s = vega.scale('sequential-linear')().domain(d).interpolator(vega.scheme(name)).clamp(clamp);
    const probe = [-20, 0, 5, 10, 12.5, 15, 20, 50, 100, 150];
    lines.push(`seq|${name}|${hx(d)}|${clamp ? 1 : 0}|${hx(probe)}|${probe.map((x) => s(x)).join(' ')}`);
  }
  // discretised ordinal ramp (quantizeInterpolator), as used for ordinal colour fields
  for (const [name, count] of [['blues', 3], ['blues', 5], ['viridis', 4], ['yellowgreenblue', 7]]) {
    const q = vega.quantizeInterpolator(vega.scheme(name), count);
    lines.push(`quant|${name}|${count}|${q.join(' ')}`);
  }

  // CSS colour names as known to d3-color (inlined in the vega-scale build)
  const build = fs.readFileSync(require.resolve('vega-scale/package.json').replace('package.json', 'build/vega-scale.js'), 'utf8');
  const a = build.indexOf('var named = {');
  const b = build.indexOf('};', a);
  const named = vm.runInNewContext('(' + build.slice(a + 'var named = '.length, b + 1) + ')');
  let ncs =
    '// GENERATED FILE. DO NOT EDIT.\n' +
    '// Regenerate with: cd scripts && npm ci && npm run fixtures\n' +
    '// CSS colour keywords as defined by d3-color (ISC).\n\n///|\nfn named_color(name : String) -> Int? {\n  match name {\n';
  for (const [k, v] of Object.entries(named)) ncs += `    "${k}" => Some(0x${v.toString(16).padStart(6, '0')})\n`;
  ncs += '    _ => None\n  }\n}\n';
  return {
    fixtures: { scalecases: { cases: lines.join('\n') } },
    sources: { 'scale/palettes.mbt': src, 'scale/named_colors.mbt': ncs },
  };
}
