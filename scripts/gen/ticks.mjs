// Fixtures for stats/: d3-array ticks, tickIncrement and tickStep.
import { ticks, tickIncrement, tickStep } from 'd3-array';
import { makeRng, hex16 } from '../lib/prng.mjs';

const hexList = (xs) => (xs.length ? xs.map(hex16).join(',') : '-');

export function generate() {
  const rng = makeRng(0x1234567n);
  const rnd = () => Number(rng() % 1000000007n) / 1000000007;
  const triples = [];
  const counts = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 0.5, 0.75, 1.5, 1.99, 2.5, 7.25, 0, -1, 100];

  // hand-picked ranges typical for charts
  const specials = [
    [0, 1], [0, 10], [0, 100], [0, 55], [0, 28], [-5, 5], [1, 1], [0, 0], [3, 3.0000001], [0.1, 0.2],
    [1e-9, 5e-9], [1e9, 5e9], [-1e21, 1e21], [0, 1e-7], [12345.678, 12345.679], [-100, 0], [10, 0], [5, -5],
    [0.5, 0.5000001], [1, 1000], [0, 9.999999999], [0, 10.000000001], [0, 99.99999999], [0, 100.00000001],
    [-0.3, 0.3], [1.7976931348623157e308, 1.7976931348623157e308], [0, 3.5], [0, 8], [1e-300, 2e-300],
  ];
  for (const [a, b] of specials) for (const c of counts) triples.push([a, b, c]);

  // random ranges at many magnitudes, both directions
  for (let i = 0; i < 1200; i++) {
    const mag = 10 ** (Math.floor(rnd() * 24) - 9);
    const a = (rnd() - 0.3) * mag * (rnd() < 0.5 ? 1 : 10);
    const b = a + rnd() * mag * (rnd() < 0.2 ? 0.001 : 10);
    const c = counts[Math.floor(rnd() * counts.length)];
    triples.push(rnd() < 0.2 ? [b, a, c] : [a, b, c]);
  }
  // ranges whose step lands next to powers of ten (sensitive to log10 / pow)
  for (let k = -12; k <= 15; k++) {
    for (const f of [1, 2, 5, 9.999999, 10.000001, 3.1622776, 3.1622777, 7.0710678, 7.0710679, 1.4142135, 1.4142136]) {
      const step = f * 10 ** k;
      for (const c of [5, 10]) triples.push([0, step * c, c], [step, step * (c + 1), c]);
    }
  }

  const lines = [];
  for (const [a, b, c] of triples) {
    const head = `${hex16(a)} ${hex16(b)} ${hex16(c)}`;
    lines.push(`ticks ${head} ${hexList(ticks(a, b, c))}`);
    lines.push(`inc ${head} ${hex16(tickIncrement(a, b, c))}`);
    lines.push(`step ${head} ${hex16(tickStep(a, b, c))}`);
  }
  return { fixtures: { ticks: { cases: lines.join('\n') } } };
}
