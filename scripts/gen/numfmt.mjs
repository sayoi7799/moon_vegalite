// Fixtures for util/: JS Number -> String, Math.round, and ~~x semantics.
import { makeRng, bitsToDouble, hex16 } from '../lib/prng.mjs';

export function generate() {
  const rng = makeRng();
  const values = [
    0, -0, 1, -1, 0.5, -0.5, 1.5, 2.5, -1.5, -2.5, 0.1, 0.2, 0.1 + 0.2, 100, 1e21, 1e20, 1e21 - 1e6,
    123456789012345680000, 1e-6, 1e-7, 9.999999e-7, 1.5e-7, 5e-324, 1.7976931348623157e308,
    Number.MAX_SAFE_INTEGER, Number.MIN_SAFE_INTEGER, 2 ** 31, 2 ** 31 - 1, -(2 ** 31), -(2 ** 31) - 1,
    2 ** 32, 2 ** 32 + 5, 2 ** 53, 2 ** 52 + 0.5, 4503599627370495.5, 0.49999999999999994,
    -0.49999999999999994, 4.35, 1 / 3, 2 / 3, 1234.5678, 0.000123456, 1e100, 1e-100, NaN, Infinity, -Infinity,
  ];
  // random bit patterns (finite only)
  for (let i = 0; i < 1500; i++) {
    const x = bitsToDouble(rng());
    if (Number.isFinite(x)) values.push(x);
  }
  // "nice" decimals as they appear in charts: k / 10^j
  for (let i = 0; i < 1500; i++) {
    const k = Number(rng() % 2000001n) - 1000000;
    const j = Number(rng() % 9n);
    values.push(k / 10 ** j);
  }
  // integers and halves of various magnitudes
  for (let i = 0; i < 400; i++) {
    const m = Number(rng() % 1000000000000n);
    values.push(m, -m, m + 0.5, -m - 0.5, m * 1e9);
  }
  // around the exponent-format boundaries
  for (let e = -9; e <= 23; e++) {
    for (const m of [1, 1.5, 9.99, 123.456]) values.push(m * 10 ** e, -m * 10 ** e);
  }

  const lines = [];
  for (const x of values) lines.push(`numstr ${hex16(x)} ${String(x)}`);
  for (const x of values) lines.push(`round ${hex16(x)} ${hex16(Math.round(x))}`);
  for (const x of values) lines.push(`int32 ${hex16(x)} ${~~x}`);
  return { numfmt: { cases: lines.join('\n') } };
}
