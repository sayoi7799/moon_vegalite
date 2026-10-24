// Fixtures for util/: Math.log, Math.log10 and Math.pow(10, k) as computed by V8 (fdlibm).
import { makeRng, bitsToDouble, hex16 } from '../lib/prng.mjs';

export function generate() {
  const rng = makeRng(0xabcdefn);
  const rnd = () => Number(rng() % 1000000007n) / 1000000007;
  const xs = [
    1, 2, 0.5, 10, 100, 1000, 1e5, 1e10, 1e15, 1e22, 1e23, 1e100, 1e-5, 1e-10, Math.E, Math.PI, 3, 5, 7, 0.1, 0.3,
    5e-324, 2.2250738585072014e-308, 1e-320, 1.7976931348623157e308, 0, -0, -1, NaN, Infinity, -Infinity, 9.999999999999999,
    10.000000000000002, 999.9999999999999, 1000.0000000000001,
  ];
  for (let k = -40; k <= 40; k++) xs.push(10 ** k, Number(`1e${k}`), 2 ** k, 3 * 10 ** k);
  for (let i = 0; i < 1500; i++) xs.push(rnd() * 10 ** (Math.floor(rnd() * 40) - 15));
  for (let i = 0; i < 500; i++) {
    const x = bitsToDouble(rng());
    if (!Number.isNaN(x)) xs.push(x);
  }
  const lines = [];
  for (const x of xs) {
    lines.push(`log ${hex16(x)} ${hex16(Math.log(x))}`);
    lines.push(`log10 ${hex16(x)} ${hex16(Math.log10(x))}`);
  }

  // table of Math.pow(10, k) for every integer exponent that can produce a finite or subnormal result
  const bits = [];
  for (let k = -330; k <= 310; k++) bits.push(hex16(Math.pow(10, k)));
  const source =
    '// GENERATED FILE. DO NOT EDIT.\n' +
    '// Regenerate with: cd scripts && npm ci && npm run fixtures\n' +
    '// Bit patterns of JavaScript Math.pow(10, k) (V8) for k in [-330, 310].\n\n' +
    '///|\nlet pow10_min_exp : Int = -330\n\n' +
    '///|\nlet pow10_max_exp : Int = 310\n\n' +
    '///|\nlet pow10_bits : Array[UInt64] = [\n' +
    bits.map((b) => `  0x${b}UL,`).join('\n') + '\n]\n';
  // sin / cos of whole degrees converted with the same constant the scenegraph uses
  const DegToRad = Math.PI / 180;
  const trigBits = (f) => {
    const out = [];
    for (let k = -720; k <= 720; k++) out.push('0x' + hex16(f(k * DegToRad)) + 'UL');
    return out;
  };
  const trig =
    '// GENERATED FILE. DO NOT EDIT.\n' +
    '// Regenerate with: cd scripts && npm ci && npm run fixtures\n' +
    '// Bit patterns of JavaScript Math.cos / Math.sin of (k * Math.PI / 180) for k in [-720, 720].\n\n' +
    '///|\nlet cos_deg_bits : Array[UInt64] = [\n  ' + trigBits(Math.cos).join(',\n  ') + ',\n]\n\n' +
    '///|\nlet sin_deg_bits : Array[UInt64] = [\n  ' + trigBits(Math.sin).join(',\n  ') + ',\n]\n';
  return {
    fixtures: { libm: { cases: lines.join('\n') } },
    sources: { 'util/pow10_table.mbt': source, 'util/trig_table.mbt': trig },
  };
}
