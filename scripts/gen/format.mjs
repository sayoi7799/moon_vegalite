// Fixtures for format/: JS Number#toFixed/toExponential/toPrecision, d3-format (via the vega locale),
// vega-format formatFloat / formatSpan.
import * as vega from 'vega';
import { makeRng, bitsToDouble, hex16 } from '../lib/prng.mjs';

const BACKSLASH = String.fromCharCode(92);

/** Escape so a result fits on one printable-ASCII line without the '|' separator. */
function esc(s) {
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c >= 0x20 && c <= 0x7e && s[i] !== BACKSLASH && s[i] !== '|') out += s[i];
    else out += BACKSLASH + 'u' + c.toString(16).padStart(4, '0');
  }
  return out;
}

export function generate() {
  const rng = makeRng(0xf00dn);
  const rnd = () => Number(rng() % 1000000007n) / 1000000007;
  const locale = vega.locale();

  const values = [
    0, -0, 1, -1, 0.5, -0.5, 1.5, 2.5, 3.5, 0.05, 0.15, 0.25, 0.35, 1.005, 1.45, 8.345, 10.235, 0.1, 0.2, 0.3,
    0.1 + 0.2, 0.7, 12, 99.5, 99.95, 99.995, 100, 123, 999.5, 999.9999, 1000, 1234, 12345.6789, -12345.6789,
    0.000123, 0.00000123, 1e-7, 1.5e-7, 9.5e-7, 1e-10, 1e-15, 5e-324, 1e5, 1e6, 999999.5, 1e9, 123456789, 123456789.12345678,
    1e15, 1e20, 999999999999999900000, 1e21, 1.234e21, 1.2345678901234567e25, 1e100, 1.7976931348623157e308, 4.35, 0.045,
    1 / 3, 2 / 3, Math.PI, Math.E, 2 ** 31, 2 ** 53, -(2 ** 53), 255, 4095, 65535, 0.99999, 9.99999, 0.000999999, 7.5e-5,
    NaN, Infinity, -Infinity,
  ];
  for (let i = 0; i < 160; i++) values.push((rnd() - 0.5) * 10 ** (Math.floor(rnd() * 24) - 10));
  for (let i = 0; i < 60; i++) {
    const x = bitsToDouble(rng());
    if (Number.isFinite(x)) values.push(x);
  }
  for (let i = 0; i < 80; i++) values.push(Number((Math.floor(rnd() * 2e6) - 1e6) / 10 ** Math.floor(rnd() * 6)));

  const lines = [];

  // 1. exact decimal conversions
  const fixedValues = values.filter((v, i) => i % 1 === 0);
  for (const v of fixedValues) {
    for (const f of [0, 1, 2, 3, 5, 8, 12, 20]) lines.push(`fixed|${hex16(v)}|${f}|${esc(v.toFixed(f))}`);
    lines.push(`fixed|${hex16(v)}|100|${esc(v.toFixed(100))}`);
    lines.push(`exp|${hex16(v)}|-|${esc(v.toExponential())}`);
    for (const f of [0, 1, 2, 3, 6, 12, 20]) lines.push(`exp|${hex16(v)}|${f}|${esc(v.toExponential(f))}`);
    for (const p of [1, 2, 3, 4, 6, 10, 12, 21]) lines.push(`prec|${hex16(v)}|${p}|${esc(v.toPrecision(p))}`);
  }

  // 2. d3-format via the vega locale
  const specs = [
    '', ',', 'd', ',d', '+d', '(d', ' d', 'f', '.0f', '.1f', '.2f', ',.2f', '+.2f', '(.2f', ' .2f', '$,.2f', '$.0f', '08.2f',
    '0>10.2f', '*^12,.1f', '<12d', '^12d', '>12d', '=+12.2f', '=12,.2f', '012,.2f', '.2~f', '.3~f', '~f', 'e', '.3e', '.0e', '~e',
    '.2~e', 'g', '.4g', '.12g', '~g', ',g', 'n', '.3n', 'r', '.3r', '.5r', '~r', 'p', '.2p', '.0p', '%', '.1%', '.0%', ',.1%',
    '~%', 's', '.0s', '.1s', '.2s', '.3s', '.4s', '.6s', '~s', '.3~s', '$.2s', 'x', 'X', 'o', 'b', '#x', '#b', '#o', '#X', 'c',
    '.2', '.5', '5', '08', ',.0f', '.12', '.12~', '<5', '+', '(', '$', 'z', '.3z',
  ];
  const fmtValues = values.filter((_, i) => i % 3 === 0 || i < 70);
  for (const spec of specs) {
    const fmt = locale.format(spec);
    for (const v of fmtValues) {
      // vega's d3-format 3.1.0 reads a stale module-level prefixExponent for NaN/Infinity with type s
      if (/s$/.test(spec) && !Number.isFinite(v)) continue;
      lines.push(`fmt|${spec}|${hex16(v)}|${esc(fmt(v))}`);
    }
  }

  // 3. vega formatFloat
  for (const spec of ['', ',', '%', 'e', 's', '.3']) {
    const fmt = locale.formatFloat(spec);
    for (const v of values) {
      if (/s$/.test(spec) && !Number.isFinite(v)) continue;
      lines.push(`float|${spec}|${hex16(v)}|${esc(fmt(v))}`);
    }
  }

  // 4. vega formatSpan (the default tick label formatter)
  const spans = [
    [0, 100, 10], [0, 1, 10], [0, 1, 5], [-5, 5, 10], [0, 55, 5], [0, 1e6, 10], [0, 0.001, 10], [0, 1e-7, 5], [1e9, 5e9, 8],
    [-1e21, 1e21, 6], [0.5, 0.5, 5], [0, 0.5, 4], [12345, 12400, 6], [-0.05, 0.05, 10], [0, 3.5, 7], [100, 0, 5],
  ];
  const spanSpecs = [undefined, ',f', 's', '~s', '.1s', '%', '.1%', 'e', 'g', 'r', '', 'f', 'p', '$,f', '+,f'];
  const spanValues = [0, 1, -1, 0.5, 2.5, 5, 10, 25, 50, 100, -100, 0.001, 1500, 123456, 1e6, -2e-7, 0.05, 3.5, 12400];
  for (const [a, b, c] of spans) {
    for (const sp of spanSpecs) {
      const fmt = locale.formatSpan(a, b, c, sp);
      lines.push(`span|${hex16(a)} ${hex16(b)} ${hex16(c)}|${sp === undefined ? '-' : sp}|` + spanValues.map((v) => esc(fmt(v))).join('~'));
    }
  }
  return { fixtures: { formatcases: { cases: lines.join('\n') } } };
}
