// Fixtures for time/: calendar arithmetic (JS Date), vega-time intervals and floors, the utc time
// scale (ticks, nice, default label format), and d3-time-format formatting/parsing via the vega locale.
// All instants are integer milliseconds since the epoch, written in decimal ("NaN" for Invalid Date).
import * as vega from 'vega';
import { makeRng } from '../lib/prng.mjs';

const ms = (d) => {
  const v = d instanceof Date ? d.getTime() : Number(d);
  return Number.isNaN(v) ? 'NaN' : String(v);
};
const list = (xs) => (xs.length ? xs.map(ms).join(',') : '-');

export function generate() {
  const rng = makeRng(0x7157n);
  const rnd = () => Number(rng() % 1000000007n) / 1000000007;
  const U = Date.UTC;

  // instants: boundaries plus random points between 1850 and 2100, and some far away
  const times = [
    0, -1, 1, 86399999, 86400000, U(1999, 11, 31, 23, 59, 59, 999), U(2000, 0, 1), U(2000, 1, 29), U(2000, 1, 29, 12),
    U(2001, 0, 1), U(2012, 0, 1), U(2012, 11, 31), U(2016, 1, 29, 5, 6, 7, 8), U(2100, 1, 28), U(1900, 0, 1),
    U(1969, 11, 31, 23, 59, 59, 999), U(1850, 5, 15), U(-100, 0, 1), U(275000, 0, 1), -62135596800000, 253402300799999,
  ];
  for (let y = 2015; y <= 2024; y++) times.push(U(y, 0, 1), U(y, 0, 1, 0, 0, 0, 1), U(y, 11, 31, 23, 59, 59, 999));
  for (let i = 0; i < 400; i++) times.push(Math.floor(U(1850, 0, 1) + rnd() * (U(2100, 0, 1) - U(1850, 0, 1))));
  for (let i = 0; i < 40; i++) times.push(Math.floor((rnd() - 0.5) * 2e14));

  const lines = [];

  // calendar fields and Date.UTC normalisation
  for (const t of times) {
    const d = new Date(t);
    lines.push(`parts|${t}|${[d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), d.getUTCDay(), d.getUTCHours(), d.getUTCMinutes(), d.getUTCSeconds(), d.getUTCMilliseconds()].join(',')}`);
  }
  const utcArgs = [
    [2020, 0, 1, 0, 0, 0, 0], [2020, 12, 1, 0, 0, 0, 0], [2020, -1, 1, 0, 0, 0, 0], [2020, 1, 30, 0, 0, 0, 0], [2020, 0, 0, 0, 0, 0, 0],
    [2020, 0, 1, 25, 61, 61, 1001], [2020, 0, 400, 0, 0, 0, 0], [99, 0, 1, 0, 0, 0, 0], [0, 0, 1, 0, 0, 0, 0], [100, 0, 1, 0, 0, 0, 0],
    [1969, 11, 31, 23, 59, 59, 999], [-1, 0, 1, 0, 0, 0, 0], [275760, 8, 13, 0, 0, 0, 0], [275760, 8, 14, 0, 0, 0, 0], [2012, 1, -1, 0, 0, 0, 0],
    [2012, 25, 5, 0, 0, 0, 0], [2012, 0, 1, 0, 0, 0, -1],
  ];
  for (const a of utcArgs) lines.push(`utcms|${a.join(',')}|${ms(U(...a))}`);

  // vega-time intervals
  const units = ['year', 'quarter', 'month', 'week', 'date', 'hours', 'minutes', 'seconds', 'milliseconds'];
  const sample = times.filter((_, i) => i % 7 === 0);
  const spans = { year: 1e11, quarter: 4e10, month: 1.5e10, week: 4e9, date: 1e9, hours: 4e7, minutes: 2e6, seconds: 4e4, milliseconds: 90 };
  for (const u of units) {
    const iv = vega.utcInterval(u);
    for (const t of sample) {
      lines.push(`ival|${u}|floor|${t}|${ms(iv.floor(new Date(t)))}`);
      lines.push(`ival|${u}|ceil|${t}|${ms(iv.ceil(new Date(t)))}`);
      for (const s of [-3, 1, 5]) lines.push(`ival|${u}|offset|${t},${s}|${ms(iv.offset(new Date(t), s))}`);
    }
    for (const t of sample.slice(0, 14)) {
      const span = Math.floor(spans[u] * (1 + Math.floor(rnd() * 8)));
      for (const step of [1, 2]) lines.push(`ival|${u}|range|${t},${t + span},${step}|${list(iv.range(new Date(t), new Date(t + span), step))}`);
    }
    if (typeof iv.every === 'function') {
      for (const k of [2, 3, 5, 6, 7, 10, 15, 30]) {
        const ev = iv.every(k);
        if (!ev) continue;
        for (const t of sample.slice(0, 10)) {
          lines.push(`ival|${u}/${k}|floor|${t}|${ms(ev.floor(new Date(t)))}`);
          lines.push(`ival|${u}/${k}|ceil|${t}|${ms(ev.ceil(new Date(t)))}`);
          const span = Math.floor(spans[u] * (3 + Math.floor(rnd() * 8)));
          lines.push(`ival|${u}/${k}|range|${t},${t + span},1|${list(ev.range(new Date(t), new Date(t + span), 1))}`);
        }
      }
    }
  }
  // counts between pairs of instants
  for (const u of units) {
    const iv = vega.utcInterval(u);
    if (typeof iv.count !== 'function') continue;
    for (let i = 0; i + 1 < sample.length; i += 2) {
      const a = Math.min(sample[i], sample[i + 1]), b = Math.max(sample[i], sample[i + 1]);
      lines.push(`ival|${u}|count|${a},${b}|${ms(iv.count(new Date(a), new Date(b)))}`);
    }
  }

  // vega-time floors (units combinations and steps)
  const unitSets = [
    ['year'], ['month'], ['quarter'], ['date'], ['day'], ['week'], ['dayofyear'], ['hours'], ['minutes'], ['seconds'], ['milliseconds'],
    ['year', 'month'], ['year', 'quarter'], ['year', 'month', 'date'], ['year', 'week'], ['year', 'week', 'day'], ['year', 'dayofyear'],
    ['month', 'date'], ['hours', 'minutes'], ['hours', 'minutes', 'seconds'], ['year', 'month', 'date', 'hours'],
    ['year', 'month', 'date', 'hours', 'minutes'], ['year', 'month', 'date', 'hours', 'minutes', 'seconds'], ['quarter', 'month'],
    ['date', 'hours'], ['day', 'hours'],
  ];
  const fsample = times.filter((_, i) => i % 9 === 0 && times[i] > -8e13 && times[i] < 8e13);
  for (const us of unitSets) {
    for (const step of [1, 2, 3]) {
      let f;
      try { f = vega.utcFloor(us, step); } catch { continue; }
      for (const t of fsample) lines.push(`floor|${us.join('+')}|${step}|${t}|${ms(f(t))}`);
    }
  }

  // time scale: ticks, nice and default tick labels
  const locale = vega.locale();
  const domains = [
    [U(2000, 0, 1), U(2010, 0, 1)], [U(2000, 0, 1), U(2000, 6, 1)], [U(2000, 0, 1), U(2000, 0, 8)], [U(2000, 0, 1), U(2000, 0, 2)],
    [U(2000, 0, 1, 0, 0), U(2000, 0, 1, 3, 0)], [U(2000, 0, 1, 0, 0, 0), U(2000, 0, 1, 0, 5, 0)], [U(2000, 0, 1, 0, 0, 0), U(2000, 0, 1, 0, 0, 30)],
    [U(2000, 0, 1, 0, 0, 0, 0), U(2000, 0, 1, 0, 0, 0, 800)], [U(1900, 0, 1), U(2100, 0, 1)], [U(2012, 2, 3, 4, 5), U(2012, 2, 17, 5, 6)],
    [U(2000, 0, 1), U(2000, 0, 1)], [U(2010, 0, 1), U(2000, 0, 1)], [U(1970, 0, 1), U(2022, 5, 5)], [U(2000, 0, 31), U(2000, 3, 1)],
    [U(2013, 11, 20), U(2014, 0, 12)], [U(0, 0, 1), U(500, 0, 1)], [U(-500, 0, 1), U(500, 0, 1)],
  ];
  for (let i = 0; i < 60; i++) {
    const a = U(1950, 0, 1) + Math.floor(rnd() * 2e12);
    domains.push([a, a + Math.floor(rnd() * 10 ** (3 + rnd() * 10))]);
  }
  for (const [a, b] of domains) {
    const sc = vega.scale('utc')();
    sc.domain([a, b]);
    for (const c of [2, 5, 10, 20]) {
      const ticks = sc.ticks(c);
      lines.push(`ticks|${a},${b},${c}|${list(ticks)}`);
      const fmt = locale.utcFormat(undefined);
      lines.push(`labels|${a},${b},${c}|${ticks.map((t) => fmt(t)).join('~')}`);
      const sn = vega.scale('utc')();
      sn.domain([a, b]);
      sn.nice(c);
      lines.push(`nice|${a},${b},${c}|${sn.domain().map(ms).join(',')}`);
    }
  }

  // d3-time-format: formatting
  const fspecs = [
    '%Y', '%y', '%m', '%d', '%e', '%H', '%I', '%M', '%S', '%L', '%f', '%b', '%B', '%a', '%A', '%j', '%p', '%q', '%Q', '%s', '%u', '%U', '%V', '%w', '%W',
    '%g', '%G', '%Z', '%%', '%x', '%X', '%c', '%-d', '%_d', '%0e', '%-m', '%_H', '%-I', '%-j', '%Y-%m-%d', '%Y-%m-%dT%H:%M:%S', '%b %d, %Y', '%I:%M %p',
    '%a %d', '%B %Y', 'plain', '%z', '%-', '%', 'Week %U of %Y', '%d/%m/%y', '%H:%M:%S.%L', '%-d %b',
  ];
  const ftimes = times.filter((_, i) => i % 4 === 0 && times[i] > -9e13 && times[i] < 9e13);
  for (const sp of fspecs) {
    const f = locale.utcFormat(sp);
    for (const t of ftimes) lines.push(`fmt|${sp}|${t}|${f(new Date(t)).replace(/[^\x20-\x7e]/g, (c) => '?')}`);
  }

  // d3-time-format: parsing
  const pcases = [
    ['%Y-%m-%d', ['2020-02-29', '2020-13-01', '1999-12-31', '2020-2-3', '20200229', '2020-02-29x', '', '0001-01-01']],
    ['%Y/%m/%d', ['2012/01/01', '2012/1/1', '2012-01-01']],
    ['%d/%m/%Y', ['31/12/1999', '01/02/2003', '32/01/2000']],
    ['%m/%d/%Y', ['12/31/1999', '1/2/2003', ' 3/ 4/2005']],
    ['%Y-%m-%dT%H:%M:%S', ['2020-02-29T12:34:56', '2020-02-29T24:00:00', '2020-02-29T12:34']],
    ['%Y-%m-%dT%H:%M:%SZ', ['2020-02-29T12:34:56Z', '2020-02-29T12:34:56']],
    ['%Y-%m-%dT%H:%M:%S%Z', ['2020-02-29T12:34:56+0100', '2020-02-29T12:34:56-05:30', '2020-02-29T12:34:56Z']],
    ['%b %d, %Y', ['Jan 1, 2000', 'Feb 29, 2020', 'jan 01, 2000', 'Foo 1, 2000']],
    ['%B %d %Y', ['March 5 2001', 'march 5 2001', 'Mar 5 2001']],
    ['%a %b %d %Y', ['Sat Jan 01 2000', 'sat jan 01 2000']],
    ['%I:%M %p', ['12:00 AM', '12:00 PM', '1:05 pm', '11:59 PM']],
    ['%H:%M:%S.%L', ['01:02:03.004', '23:59:59.999']],
    ['%y', ['68', '69', '00', '99']],
    ['%Y', ['2000', '99', '12345']],
    ['%j', ['001', '366', '060']],
    ['%Y %j', ['2020 060', '2021 060']],
    ['%Y-%U-%w', ['2020-09-6', '2021-00-0']],
    ['%Y-%W-%u', ['2020-09-6', '2021-00-1']],
    ['%G-W%V-%u', ['2020-W09-6', '2021-W01-1']],
    ['%Q', ['1500000000000', '0']],
    ['%s', ['1500000000', '0']],
    ['%x', ['1/2/2003', '12/31/1999']],
    ['%X', ['1:02:03 PM', '12:00:00 AM']],
    ['%c', ['1/2/2003, 1:02:03 PM']],
    ['%q-%Y', ['2-2000', '4-1999']],
    ['%m%d', ['0229', '1231']],
    ['%e', [' 5', '15']],
  ];
  const parse = (sp, s) => {
    const r = locale.utcParse(sp)(s);
    return r == null ? 'null' : ms(r);
  };
  for (const [sp, strs] of pcases) for (const s of strs) lines.push(`parse|${sp}|${s}|${parse(sp, s)}`);

  return { fixtures: { timecases: { cases: lines.join('\n') } } };
}
