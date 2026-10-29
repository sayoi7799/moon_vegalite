// The specifications of the benchmarks (the same ones bench/data.mbt generates, checked by a checksum).
const next = (s) => (s * 48271) % 2147483647; // below 2^47, exact in a double

export function aggregateBarSpec(rows = 10000) {
  let s = 1;
  const out = [];
  for (let i = 0; i < rows; i++) {
    s = next(s);
    const category = s % 20;
    s = next(s);
    const value = s % 10000;
    out.push(`{"cat":"c${category}","v":${value}}`);
  }
  return `{"data":{"values":[${out.join(',')}]},"mark":"bar","encoding":{"x":{"field":"cat","type":"nominal"},"y":{"aggregate":"mean","field":"v","type":"quantitative"}}}`;
}

export function scatterSpec(points = 100000) {
  let s = 1;
  const out = [];
  for (let i = 0; i < points; i++) {
    s = next(s);
    const x = s % 10000;
    s = next(s);
    const y = s % 10000;
    out.push(`{"x":${x},"y":${y}}`);
  }
  return `{"data":{"values":[${out.join(',')}]},"mark":"point","encoding":{"x":{"field":"x","type":"quantitative"},"y":{"field":"y","type":"quantitative"}}}`;
}

/** 32-bit FNV-1a of the code units of a string. */
export function checksum(text) {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619) >>> 0;
  return h;
}

export const SCENARIOS = {
  aggregate_bar_10k: { title: '10,000 rows, mean per category, bar chart', spec: () => aggregateBarSpec(10000) },
  scatter_100k: { title: '100,000-point scatter plot', spec: () => scatterSpec(100000) },
};
