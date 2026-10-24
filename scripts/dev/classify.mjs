// List which official examples fall inside the supported subset, with feature tags.
import fs from 'node:fs';
import path from 'node:path';
const dir = process.argv[2];
const MARKS = new Set(['bar', 'line', 'point', 'area', 'rule', 'tick', 'rect', 'text', 'circle', 'square']);
const CH = new Set(['x', 'y', 'x2', 'y2', 'color', 'size', 'shape', 'opacity', 'text']);
const TF = new Set(['filter', 'calculate', 'aggregate', 'bin', 'timeUnit', 'fold']);
const out = [];
for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.vl.json')).sort()) {
  const s = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
  const why = [];
  for (const k of ['layer', 'facet', 'concat', 'hconcat', 'vconcat', 'repeat', 'params', 'selection', 'projection', 'transform', 'resolve'])
    if (k in s && k !== 'transform') why.push(k);
  if (s.transform) for (const t of s.transform) { const k = Object.keys(t).find((k) => TF.has(k)); if (!k || Object.keys(t).some((x) => !TF.has(x) && !['as', 'groupby', 'bin', 'field', 'timeUnit', 'filter', 'calculate', 'aggregate', 'fold'].includes(x))) why.push('transform:' + Object.keys(t).join('+')); }
  const m = typeof s.mark === 'string' ? s.mark : s.mark?.type;
  if (!MARKS.has(m)) why.push('mark:' + m);
  for (const [c, d] of Object.entries(s.encoding ?? {})) {
    if (!CH.has(c)) why.push('ch:' + c);
    else if (d && (d.condition || d.value === undefined && !d.field && !d.aggregate && d.datum === undefined && !d.bin)) why.push('def:' + c);
  }
  const u = s.data?.url;
  if (u && !/\.(csv|json)$/.test(u)) why.push('data:' + u);
  if (!s.data) why.push('nodata');
  if (u && /\.json$/.test(u) && s.data.format) why.push('format');
  out.push([f, why]);
}
const ok = out.filter(([, w]) => !w.length).map(([f]) => f);
console.log(ok.length, 'in subset');
console.log(ok.join('\n'));
