// Fixtures for expr/: expressions evaluated by vega's own expression engine (formula transform).
import * as vega from 'vega';
import { escLine } from '../lib/mbt.mjs';
import { hex16 } from '../lib/prng.mjs';

const rows = [
  { a: 1, b: 2, s: 'x', t: 'Hello World', n: null, d: '2020-03-15', f: 2.5, neg: -3.7, 'a b': 7, o: { x: 1, y: { z: 'deep' } }, arr: [10, 20, 30], z: 0, e: '', flag: true },
  { a: -5, b: 0, s: '10', t: 'abc', n: null, d: '2000-02-29T12:34:56Z', f: 0.1, neg: -0.5, 'a b': 8, o: { x: 2 }, arr: [], z: 0, e: '', flag: false },
  { a: 0.5, b: 3, s: 'abc', t: '', d: '1999-12-31', f: 1e21, neg: 1e-7, 'a b': 0, o: {}, arr: [1], z: 0, e: 'e', flag: true },
  { a: 1e10, b: -1, s: ' 42 ', t: 'The Quick Brown Fox', d: 'not a date', f: 123.456, neg: -1000, 'a b': -1, arr: [5, 6], z: 1, e: '0', flag: false },
  { a: 3, b: 3, s: '3', t: 'aaa', d: 'Jan 1 2001', f: 0, neg: 0, 'a b': 3, o: { x: null }, arr: [0], z: -0, e: 'false', flag: true },
  {},
  { a: null, b: null, s: null, t: null, d: null, f: null, neg: null, 'a b': null, o: null, arr: null, z: null, e: null, flag: null },
];

const exprs = [
  // arithmetic and coercion
  'datum.a + datum.b', 'datum.a - datum.b', 'datum.a * datum.b', 'datum.a / datum.b', 'datum.a % datum.b', '-datum.a', '+datum.s', '+datum.t', '!datum.a',
  '~datum.a', 'datum.a + datum.s', 'datum.s + 1', 'datum.s + datum.t', 'datum.s - 1', 'datum.s * datum.s', 'datum.n + 1', 'datum.m + 1', 'datum.n + datum.n',
  '1 + 2 * 3', '(1 + 2) * 3', '2 / 0', '-2 / 0', '0 / 0', '5 % 0', '-5 % 3', '5.5 % 2', '-0', '0 * -1', '1e3 + 1', '.5 + .25', '0x10 + 1', '1 - -1', '- -2',
  'datum.f * 3', 'datum.f / 3', 'datum.neg % 2', 'datum.a + datum.b + datum.s', 'datum.flag + 1', 'datum.flag + datum.flag', 'datum.e + 1', 'datum.e * 1', '"5" * "4"',
  '"5" + "4"', '"5" - "4"', "'it\\'s'", '"tab\\there"', '"uni\\u00e9"', '"line\\nbreak"',
  // comparison
  'datum.a < datum.b', 'datum.a <= datum.b', 'datum.a > datum.b', 'datum.a >= datum.b', 'datum.s < datum.t', 'datum.s > datum.t', 'datum.a == datum.s', 'datum.a != datum.s',
  'datum.a === datum.s', 'datum.a !== datum.s', 'datum.n == null', 'datum.n === null', 'datum.m == null', 'datum.n == 0', 'datum.e == 0', 'datum.e == false', 'datum.flag == 1',
  'datum.flag === true', 'datum.s == 10', 'datum.s == "10"', '"a" < "b"', '"B" < "a"', '"10" < "9"', '10 < 9', '"10" < 9', 'null < 1', 'null >= 0', 'datum.t < datum.t',
  'datum.a == datum.a', 'datum.f == datum.f', '0 == -0', '0 === -0', 'null == 0', 'null == false', 'datum.z == datum.e',
  // logic and conditional
  'datum.a && datum.b', 'datum.a || datum.b', 'datum.n || "fallback"', 'datum.n && 1', 'datum.a > 0 ? "pos" : "nonpos"', 'datum.a ? datum.b : datum.t', '!datum.s', '!!datum.t',
  'datum.a > 0 && datum.b > 0', 'datum.a > 0 || datum.b > 0', 'if(datum.a > 0, "p", "n")', 'if(datum.n, 1, 2)', 'datum.a > 0 ? datum.b > 0 ? 1 : 2 : 3',
  // bitwise
  'datum.a | datum.b', 'datum.a & datum.b', 'datum.a ^ datum.b', 'datum.a << 2', 'datum.a >> 1', 'datum.a >>> 1', '~~datum.f', '1 << 31', '1 << 32', '-1 >>> 0', '4294967296 | 0',
  // math
  'abs(datum.neg)', 'ceil(datum.f)', 'floor(datum.neg)', 'round(datum.f)', 'round(datum.neg)', 'round(-0.5)', 'round(2.5)', 'round(-2.5)', 'sqrt(datum.a)', 'sqrt(datum.b)', 'pow(datum.a, 2)',
  'pow(2, 10)', 'pow(2, 0.5)', 'exp(1)', 'exp(0)', 'log(datum.a)', 'log(1)', 'log(0)', 'log(10)', 'sin(0)', 'cos(0)', 'tan(0)', 'atan2(1, 1)', 'atan(1)', 'asin(1)', 'acos(1)', 'asin(2)',
  'min(datum.a, datum.b)', 'max(datum.a, datum.b)', 'min(1, 2, 3)', 'max(1, 2, 3)', 'max()', 'min()', 'max(datum.s, 1)', 'max(datum.n, 1)', 'min(datum.n, 1)', 'hypot(3, 4)',
  'clamp(datum.a, 0, 2)', 'clamp(datum.f, 1, 3)', 'clamp(5, 10, 0)', 'isNaN(datum.a)', 'isNaN(NaN)', 'isNaN(datum.s)', 'isNaN("x")', 'isFinite(datum.a)', 'isFinite(1/0)', 'isFinite("1")',
  'PI', 'E', 'LN2', 'LN10', 'LOG2E', 'LOG10E', 'SQRT1_2', 'SQRT2', 'MIN_VALUE', 'MAX_VALUE', 'NaN', 'PI * 2', 'floor(PI * 100) / 100',
  // validity and conversion
  'isValid(datum.a)', 'isValid(datum.n)', 'isValid(datum.m)', 'isValid(datum.e)', 'isValid(NaN)', 'isValid(0/0)', 'isValid("")', 'isNumber(datum.a)', 'isNumber(datum.s)', 'isString(datum.s)',
  'isString(datum.a)', 'isBoolean(datum.flag)', 'isBoolean(datum.a)', 'toNumber(datum.s)', 'toNumber(datum.e)', 'toNumber(datum.n)', 'toNumber(datum.t)', 'toNumber(datum.flag)',
  'toString(datum.a)', 'toString(datum.n)', 'toString(datum.e)', 'toString(datum.f)', 'toString(datum.flag)', 'toBoolean(datum.s)', 'toBoolean(datum.e)', 'toBoolean(datum.a)',
  'toBoolean(datum.n)', 'toBoolean("false")', 'toBoolean("0")', 'toBoolean(0)', 'toDate(datum.d)', 'toDate(datum.a)', 'toDate(datum.e)', 'toDate(datum.n)',
  // strings
  'length(datum.t)', 'length(datum.arr)', 'length("")', 'upper(datum.t)', 'lower(datum.t)', 'upper(datum.a)', 'trim(datum.s)', 'substring(datum.t, 1)', 'substring(datum.t, 1, 4)',
  'substring(datum.t, -2)', 'substring(datum.t, 4, 1)', 'substring(datum.t, 100)', 'indexof(datum.t, "o")', 'indexof(datum.t, "zz")', 'indexof(datum.t, "")', 'lastindexof(datum.t, "o")',
  'replace(datum.t, "o", "0")', 'replace(datum.t, "zz", "0")', 'slice(datum.t, 2)', 'slice(datum.t, -3)', 'slice(datum.t, 1, 3)', 'slice(datum.arr, 1)', 'datum.t + "!"',
  'datum.s + datum.a + datum.b', 'upper(datum.t) + lower(datum.t)',
  // member access
  'datum["a b"]', "datum['a b'] + 1", 'datum.o.x', 'datum.o.y.z', 'datum.arr[1]', 'datum.arr[5]', 'datum["a"]', 'datum.t.length', 'datum.arr.length', 'datum.t[0]', 'datum.o',
  // dates (local time is UTC when TZ=UTC)
  'year(datum.d)', 'month(datum.d)', 'date(datum.d)', 'day(datum.d)', 'hours(datum.d)', 'minutes(datum.d)', 'seconds(datum.d)', 'milliseconds(datum.d)', 'time(datum.d)',
  'utcyear(datum.d)', 'utcmonth(datum.d)', 'utcdate(datum.d)', 'utcday(datum.d)', 'utchours(datum.d)', 'year(datum.a)', 'year(0)', 'month(86400000 * 40)',
  'datetime(2020, 1, 15)', 'datetime(2020, 0, 1, 12, 30, 45, 500)', 'datetime(99, 0, 1)', 'datetime(2020, 12, 1)', 'datetime(2020)', 'utc(2020, 0, 1)', 'year(datetime(2020, 5, 1))',
  'time(datetime(2020, 5, 17))', 'year(datum.n)', 'year(datum.e)',
  // formatting
  'format(datum.f, ".2f")', 'format(datum.a, ",d")', 'format(datum.n, ".2f")', 'format(1234.5678, "$,.2f")', 'format(0.256, ".1%")', 'format(-5, "+d")', 'format(1e6, "s")', 'format(datum.m, ".2f")',
  'timeFormat(datum.d, "%Y-%m-%d")', 'timeFormat(datum.d, "%b %d, %Y")', 'timeFormat(0, "%A")', 'utcFormat(datum.d, "%H:%M")', 'timeFormat(datetime(2020, 5, 17), "%j")', 'format(datum.s, "d")',
];

function ser(v) {
  if (v === undefined || v === null) return 'z';
  if (typeof v === 'number') return 'n:' + hex16(v);
  if (typeof v === 'string') return 's:' + escLine(v);
  if (typeof v === 'boolean') return 'b:' + (v ? 1 : 0);
  if (v instanceof Date) return 'n:' + hex16(+v);
  return 'o:' + escLine(JSON.stringify(v));
}

async function evalRow(expr, row) {
  try {
    const spec = {
      $schema: 'https://vega.github.io/schema/vega/v5.json',
      data: [{ name: 't', values: [{ ...row }], transform: [{ type: 'formula', expr, as: 'out' }] }],
    };
    const view = new vega.View(vega.parse(spec), { renderer: 'none', logLevel: 0 });
    await view.runAsync();
    return ser(view.data('t')[0].out);
  } catch {
    return 'E';
  }
}

export async function generate() {
  const lines = [];
  for (const r of rows) lines.push(`row|${escLine(JSON.stringify(r))}`);
  for (const expr of exprs) {
    // a malformed expression fails to parse for every row
    const results = [];
    for (const r of rows) results.push(await evalRow(expr, r));
    lines.push(`expr|${escLine(expr)}|${results.join('|')}`);
  }
  return { fixtures: { exprcases: { cases: lines.join(String.fromCharCode(10)) } } };
}
