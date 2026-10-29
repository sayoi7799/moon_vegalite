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

  // Math.sin / cos / asin / acos / atan / atan2: the functions the arc path of d3-shape needs, bit for bit.
  const angles = [0, -0, 1e-10, 1e-300, 0.5, -0.5, 1, -1, Math.PI / 2, Math.PI, 2 * Math.PI, 3 * Math.PI / 2, 6.283185307179586, 6.28318530718, 100, 1e6, 1e15, Infinity, -Infinity, NaN];
  for (let i = 0; i < 1500; i++) angles.push((rnd() - 0.5) * 20);
  for (let i = 0; i < 300; i++) angles.push(rnd() * 2 * Math.PI);
  for (let i = 0; i < 300; i++) angles.push((rnd() - 0.5) * 1e-3);
  for (let i = 0; i < 200; i++) angles.push((rnd() - 0.5) * 1e4);
  for (const a of angles) {
    lines.push(`sin ${hex16(a)} ${hex16(Math.sin(a))}`);
    lines.push(`cos ${hex16(a)} ${hex16(Math.cos(a))}`);
    lines.push(`atan ${hex16(a)} ${hex16(Math.atan(a))}`);
  }
  const unit = [0, -0, 1, -1, 0.5, -0.5, 0.4999999999999999, -0.5000000000000001, 1.0000000000000002, -1.0000000000000002, 2, NaN, 1e-20, 2 ** -57, 2 ** -58, 0.9999999999999999, -0.9999999999999999, 0.975, 0.9749999999999999, 0.9750000000000001];
  for (let i = 0; i < 2500; i++) unit.push((rnd() - 0.5) * 2);
  for (let i = 0; i < 300; i++) unit.push((rnd() - 0.5) * 0.02);
  for (let i = 0; i < 300; i++) unit.push(1 - rnd() * 1e-3);
  for (const u of unit) {
    lines.push(`asin ${hex16(u)} ${hex16(Math.asin(u))}`);
    lines.push(`acos ${hex16(u)} ${hex16(Math.acos(u))}`);
  }
  const specials = [0, -0, 1, -1, Infinity, -Infinity, NaN, 1e-310, -1e-310, 1e300, -1e300, 2, -2, 0.5, -0.5, 1e-20, 1e20];
  const pairs = [];
  for (const y of specials) for (const x of specials) pairs.push([y, x]);
  for (let i = 0; i < 2500; i++) pairs.push([(rnd() - 0.5) * 2000, (rnd() - 0.5) * 2000]);
  for (let i = 0; i < 800; i++) { const a = rnd() * 2 * Math.PI, r = rnd() * 100; pairs.push([r * Math.sin(a), r * Math.cos(a)]); }
  for (let i = 0; i < 300; i++) pairs.push([(rnd() - 0.5) * 1e-5, (rnd() - 0.5) * 1e5]);
  for (let i = 0; i < 300; i++) pairs.push([(rnd() - 0.5) * 1e5, (rnd() - 0.5) * 1e-5]);
  for (let i = 0; i < 200; i++) pairs.push([(rnd() - 0.5) * 100, 1]);
  for (const [y, x] of pairs) lines.push(`atan2 ${hex16(y)} ${hex16(x)} ${hex16(Math.atan2(y, x))}`);

  // Table of 10^k for every integer exponent that can produce a finite or subnormal result.
  // Math.pow(10, k) is not used: V8 builds disagree on it by one ulp for a few k (Linux and macOS differ from
  // Windows, Node 22 from Node 24), so the table holds the correctly rounded value, which is the same everywhere.
  const bits = [];
  for (let k = -330; k <= 310; k++) bits.push(hex16(Number('1e' + k)));
  const source =
    '// GENERATED FILE. DO NOT EDIT.\n' +
    '// Regenerate with: cd scripts && npm ci && npm run fixtures\n' +
    '// Bit patterns of the correctly rounded 10^k, i.e. Number("1e" + k), for k in [-330, 310].\n\n' +
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
