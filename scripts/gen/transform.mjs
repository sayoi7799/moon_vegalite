// Fixtures for transform/: single vega transforms applied to small datasets, read back with view.data().
// Line formats (fields separated by '|', every free-form string escaped with escLine):
//   T|<id>|<transform json>      the vega transform object (with "type")
//   I|<id>|<row json>            one input row
//   O|<id>|k=v|k=v|...           one output row; v is  n:<hex> | s:<text> | b:0/1 | z (null) | u (undefined)
import * as vega from 'vega';
import { escLine } from '../lib/mbt.mjs';
import { hex16 } from '../lib/prng.mjs';

function ser(v) {
  if (v === undefined) return 'u';
  if (v === null) return 'z';
  if (typeof v === 'number') return 'n:' + hex16(v);
  if (typeof v === 'string') return 's:' + escLine(v);
  if (typeof v === 'boolean') return 'b:' + (v ? 1 : 0);
  if (v instanceof Date) return 'n:' + hex16(+v);
  return 's:' + escLine(JSON.stringify(v));
}

const cases = [];
let counter = 0;
function add(name, transform, rows) {
  cases.push({ id: `${name}${counter++}`, transform, rows });
}

// ---- datasets ----
const people = [
  { g: 'a', h: 'x', v: 1, s: '10' },
  { g: 'b', h: 'x', v: 5, s: 'abc' },
  { g: 'a', h: 'y', v: 3, s: '2' },
  { g: 'a', h: 'x', v: 2.5, s: '' },
  { g: 'b', h: 'y', v: null, s: null },
  { g: 'c', h: 'x', v: 7, s: '7' },
  { g: 'b', h: 'x', v: -4, s: 'zz' },
  { g: 'a', h: 'y', v: 'n/a', s: '3' },
  { g: null, h: 'x', v: 9, s: '9' },
  { h: 'y', v: 0.1 },
  { g: 'c', h: 'y', v: 0.2, s: '1' },
  { g: 'a', h: 'x', v: 100, s: 'Q' },
];
const nums = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9].map((v, i) => ({ v, w: i, g: i % 3 === 0 ? 'p' : 'q' }));
const mixed = [{ v: 1 }, { v: null }, { v: '5' }, { v: 'x' }, { v: '' }, { v: 2 }, {}, { v: 0 }, { v: -3.5 }, { v: 1e9 }];

// aggregate
const measures = [
  ['count', null], ['valid', 'v'], ['missing', 'v'], ['sum', 'v'], ['mean', 'v'], ['average', 'v'], ['min', 'v'], ['max', 'v'], ['median', 'v'], ['q1', 'v'], ['q3', 'v'],
  ['distinct', 'v'], ['variance', 'v'], ['variancep', 'v'], ['stdev', 'v'], ['stdevp', 'v'], ['stderr', 'v'], ['min', 's'], ['max', 's'], ['distinct', 's'], ['valid', 's'],
  ['missing', 's'], ['sum', 's'],
];
for (const [op, field] of measures) {
  for (const groupby of [[], ['g'], ['g', 'h']]) {
    add('agg', { type: 'aggregate', groupby, fields: [field], ops: [op], as: [`${op}_out`] }, people);
  }
}
add('agg', { type: 'aggregate', groupby: ['g'], fields: [null, 'v', 'v', 'v', 'w'], ops: ['count', 'sum', 'mean', 'median', 'max'], as: ['n', 'total', 'avg', 'med', 'top'] },
  people.map((r, i) => ({ ...r, w: i * 1.5 })));
add('agg', { type: 'aggregate', groupby: ['g'], fields: ['v', 'v', 'w'], ops: ['mean', 'sum', 'mean'] }, nums);
add('agg', { type: 'aggregate', groupby: [], fields: ['v'], ops: ['mean'] }, nums);
add('agg', { type: 'aggregate', groupby: ['v'], fields: [null], ops: ['count'] }, nums);
add('agg', { type: 'aggregate', groupby: ['v'], fields: [null], ops: ['count'] }, mixed);
add('agg', { type: 'aggregate', groupby: ['g'], fields: ['v'], ops: ['mean'] }, [{ g: 1, v: 0.1 }, { g: '1', v: 0.2 }, { g: 1, v: 0.3 }, { g: 'null', v: 5 }, { g: null, v: 6 }]);
add('agg', { type: 'aggregate', groupby: [], fields: ['v'], ops: ['mean'] }, Array.from({ length: 50 }, (_, i) => ({ v: (i * 37) % 11 / 7 })));
add('agg', { type: 'aggregate', groupby: [], fields: ['v', 'v'], ops: ['sum', 'mean'] }, Array.from({ length: 50 }, (_, i) => ({ v: 0.1 * (i % 7) })));
add('agg', { type: 'aggregate', groupby: [], fields: [null], ops: ['count'] }, []);
add('agg', { type: 'aggregate', groupby: ['g'], fields: ['v'], ops: ['sum'] }, []);

// bin
const binValues = [0, 1, 2, 3.5, 4, 5, 7.25, 9.99, 10, 12, 15, 23, 41, 55, 98.6, 100, null, '12', 'x'];
const binRows = binValues.map((v) => ({ x: v }));
for (const [extent, params] of [
  [[0, 100], { maxbins: 10 }], [[0, 100], { maxbins: 5 }], [[0, 100], { maxbins: 20 }], [[1, 99], { maxbins: 10 }], [[0, 100], { step: 7 }], [[0, 100], { maxbins: 10, nice: false }],
  [[3, 97], { maxbins: 8, nice: false }], [[0, 100], { maxbins: 10, anchor: 5 }], [[0, 1], { maxbins: 10 }], [[0.001, 0.0095], { maxbins: 10 }], [[0, 1e6], { maxbins: 10 }],
  [[5, 5], { maxbins: 10 }], [[0, 100], { maxbins: 10, minstep: 20 }], [[0, 100], { maxbins: 10, steps: [5, 10, 25] }], [[0, 100], { maxbins: 6, divide: [2] }], [[-50, 50], { maxbins: 10 }],
  [[0, 100], { maxbins: 10, base: 2 }], [[2, 13], { maxbins: 3 }], [[0, 100], { maxbins: 10, interval: false }], [[-3.7, 8.2], { maxbins: 10 }], [[0, 99], { maxbins: 100 }],
]) {
  add('bin', { type: 'bin', field: 'x', extent, as: ['bin_x', 'bin_x_end'], ...params }, binRows);
}
// extent + bin as vega-lite chains them
add('extent', { type: 'extent', field: 'x' }, binRows);

// stack
const stackRows = [
  { c: 'a', k: 'x', v: 3 }, { c: 'a', k: 'y', v: 2 }, { c: 'b', k: 'x', v: 5 }, { c: 'b', k: 'y', v: -1 }, { c: 'a', k: 'z', v: 4 }, { c: 'c', k: 'x', v: 0 },
  { c: 'b', k: 'z', v: 2.5 }, { c: 'c', k: 'y', v: -2 }, { c: 'c', k: 'z', v: 1 },
];
for (const offset of ['zero', 'center', 'normalize']) {
  add('stack', { type: 'stack', groupby: ['c'], field: 'v', offset, as: ['v0', 'v1'] }, stackRows);
  add('stack', { type: 'stack', groupby: ['c'], field: 'v', offset, sort: { field: ['k'], order: ['descending'] }, as: ['v0', 'v1'] }, stackRows);
  add('stack', { type: 'stack', groupby: ['c'], field: 'v', offset, sort: { field: ['v'], order: ['ascending'] }, as: ['v0', 'v1'] }, stackRows);
  add('stack', { type: 'stack', groupby: [], field: 'v', offset, as: ['v0', 'v1'] }, stackRows);
  add('stack', { type: 'stack', groupby: ['c', 'k'], field: 'v', offset, as: ['v0', 'v1'] }, stackRows);
}
add('stack', { type: 'stack', groupby: ['c'], offset: 'zero', as: ['v0', 'v1'] }, stackRows);
add('stack', { type: 'stack', groupby: ['c'], field: 'v', offset: 'zero', as: ['v0', 'v1'] }, [...stackRows, { c: 'a', k: 'w', v: null }, { c: 'a', k: 'q', v: 'x' }, { c: 'd', k: 'q' }]);
add('stack', { type: 'stack', groupby: ['c'], field: 'v', offset: 'normalize', as: ['v0', 'v1'] }, [{ c: 'a', v: 0 }, { c: 'a', v: 0 }, { c: 'b', v: 2 }]);

// fold
add('fold', { type: 'fold', fields: ['a', 'b'], as: ['key', 'value'] }, [{ id: 1, a: 10, b: 20 }, { id: 2, a: null, b: 'x' }, { id: 3, a: 5 }, { id: 4, b: 7 }]);
add('fold', { type: 'fold', fields: ['a', 'b', 'c'], as: ['k', 'v'] }, [{ id: 1, a: 1, b: 2, c: 3 }, { id: 2, a: 4, b: 5, c: 6 }]);
add('fold', { type: 'fold', fields: ['a'], as: ['key', 'value'] }, [{ a: 1 }, { a: 2 }, {}]);
add('fold', { type: 'fold', fields: ['o.x', 'o.y'], as: ['key', 'value'] }, [{ o: { x: 1, y: 2 } }, { o: { x: 3 } }]);

// timeunit (numbers in epoch milliseconds, UTC)
const U = Date.UTC;
const tuRows = [U(2000, 0, 1), U(2000, 1, 29, 13, 45, 6, 789), U(2012, 11, 31, 23, 59, 59, 999), U(1999, 5, 15, 12), U(2016, 2, 7), U(2020, 6, 4, 0, 0, 1), U(1970, 0, 1), U(2023, 0, 1, 5), U(2018, 9, 20, 18, 30)]
  .map((t) => ({ t }))
  .concat([{ t: null }, {}]);
for (const units of [
  ['year'], ['month'], ['quarter'], ['date'], ['day'], ['week'], ['dayofyear'], ['hours'], ['minutes'], ['seconds'], ['milliseconds'], ['year', 'month'], ['year', 'quarter'],
  ['year', 'month', 'date'], ['year', 'week'], ['year', 'week', 'day'], ['month', 'date'], ['hours', 'minutes'], ['year', 'month', 'date', 'hours'],
  ['year', 'month', 'date', 'hours', 'minutes', 'seconds'], ['quarter', 'month'],
]) {
  for (const step of [1, 2]) {
    add('tu', { type: 'timeunit', field: 't', units, step, timezone: 'utc', as: ['u0', 'u1'] }, tuRows);
  }
}
add('tu', { type: 'timeunit', field: 't', units: ['year', 'month'], step: 1, timezone: 'utc', interval: false, as: ['u0'] }, tuRows);

// filter / formula
add('filter', { type: 'filter', expr: 'datum.v > 2' }, people);
add('filter', { type: 'filter', expr: 'isValid(datum.v) && isFinite(+datum.v)' }, people);
add('filter', { type: 'filter', expr: 'datum.g == "a" || datum.s == "7"' }, people);
add('formula', { type: 'formula', expr: 'datum.v * 2', as: 'dbl' }, people);
add('formula', { type: 'formula', expr: 'toNumber(datum.s)', as: 'sn' }, people);
add('formula', { type: 'formula', expr: 'datum.g + "-" + datum.h', as: 'key' }, people);

export async function generate() {
  const lines = [];
  for (const c of cases) {
    lines.push(`T|${c.id}|${escLine(JSON.stringify(c.transform))}`);
    for (const r of c.rows) lines.push(`I|${c.id}|${escLine(JSON.stringify(r))}`);
    let out;
    try {
      const spec = {
        $schema: 'https://vega.github.io/schema/vega/v5.json',
        data: [{ name: 'src', values: c.rows.map((r) => JSON.parse(JSON.stringify(r))) }, { name: 'out', source: 'src', transform: [c.transform.type === 'extent' ? { ...c.transform, signal: 'ext' } : c.transform] }],
      };
      const view = new vega.View(vega.parse(spec), { renderer: 'none', logLevel: 0 });
      await view.runAsync();
      out = view.data('out') || [];
      if (c.transform.type === 'extent') {
        const ext = view.signal('ext');
        lines.push(`G|${c.id}|${ser(ext[0])}|${ser(ext[1])}`);
      }
    } catch (e) {
      lines.push(`X|${c.id}|${escLine(String(e.message))}`);
      continue;
    }
    for (const t of out) {
      const parts = [];
      for (const k of Object.keys(t)) {
        if (k === 'Symbol(vega_id)') continue;
        parts.push(`${escLine(k)}=${ser(t[k])}`);
      }
      lines.push(`O|${c.id}|${parts.join('|')}`);
    }
    if (out.length === 0) lines.push(`E|${c.id}`);
  }
  return { fixtures: { transformcases: { cases: lines.join(String.fromCharCode(10)) } } };
}
