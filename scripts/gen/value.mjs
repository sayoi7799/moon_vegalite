// Fixtures for value/: JavaScript ToNumber on strings and Date.parse (as used by vega's toDate).
import { escLine } from '../lib/mbt.mjs';
import { hex16 } from '../lib/prng.mjs';

export function generate() {
  const lines = [];

  const numStrings = [
    '', ' ', '0', '-0', '+0', '1', ' 12 ', '1e3', '1E-2', '.5', '5.', '+5', '-5', '0x1f', '0X1F', '0b101', '0B11', '0o17', '0O7',
    'Infinity', '-Infinity', '+Infinity', 'infinity', 'INFINITY', 'NaN', 'nan', '1_000', '1,000', '1e', 'e1', '--1', '0x', '12px',
    '\t7\n', '1.2.3', '123456789012345678901234567890', '1e400', '-1e400', '5e-324', '2e-324', '.', '+', '-', '0.1', '  3 ',
    '﻿4', '1e+3', '1e-3', '1.5e+2', '0.0000001', '1e21', '1e-7', '00012', '-00.5', '0x-1', '- 1', '1 2', 'true', 'null',
    'undefined', '0.30000000000000004', '9007199254740993', '1.7976931348623157e308', '1.7976931348623159e308', '  8',
    '0e0', '0e5', '.e1', '1.e1', '+.5', '-.5e1', '0x1fffffffffffff', '0b', '0o', '0b2', '0o8', '1f', '१२',
  ];
  for (const s of numStrings) lines.push(`tonum|${escLine(s)}|${hex16(Number(s))}`);

  // Date.parse
  const dateStrings = new Set();
  const base = [
    Date.UTC(2000, 0, 1), Date.UTC(1998, 5, 12), Date.UTC(2012, 1, 29), Date.UTC(1999, 11, 31, 23, 59, 59), Date.UTC(2010, 8, 10, 13, 5, 7),
    Date.UTC(1970, 0, 1), Date.UTC(2020, 6, 4, 0, 0, 0, 123), Date.UTC(1969, 6, 20, 20, 17, 40), Date.UTC(2038, 0, 19, 3, 14, 7),
    Date.UTC(1905, 3, 5), Date.UTC(2001, 10, 30, 12), Date.UTC(2015, 11, 25, 6, 30),
  ];
  const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const monL = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const dowL = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const p2 = (n) => String(n).padStart(2, '0');
  for (const t of base) {
    const d = new Date(t);
    const Y = d.getUTCFullYear(), M = d.getUTCMonth(), D = d.getUTCDate(), h = d.getUTCHours(), mi = d.getUTCMinutes(), s = d.getUTCSeconds(), ms = d.getUTCMilliseconds(), w = d.getUTCDay();
    const date = `${Y}-${p2(M + 1)}-${p2(D)}`;
    const time = `${p2(h)}:${p2(mi)}:${p2(s)}`;
    for (const x of [
      `${Y}`, `${Y}-${p2(M + 1)}`, date, `${date}T${p2(h)}:${p2(mi)}`, `${date}T${time}`, `${date}T${time}.${String(ms).padStart(3, '0')}`,
      `${date}T${time}Z`, `${date}T${time}.${String(ms).padStart(3, '0')}Z`, `${date}T${time}+01:00`, `${date}T${time}-05:30`, `${date}T${time}+0100`,
      `${date} ${time}`, `${date} ${p2(h)}:${p2(mi)}`, `${date}T${time}z`, ` ${date}`, `${date} `,
      `${Y}/${p2(M + 1)}/${p2(D)}`, `${Y}/${M + 1}/${D}`, `${Y}/${p2(M + 1)}/${p2(D)} ${p2(h)}:${p2(mi)}`, `${Y}/${p2(M + 1)}/${p2(D)} ${time}`,
      `${M + 1}/${D}/${Y}`, `${p2(M + 1)}/${p2(D)}/${Y}`, `${M + 1}/${D}/${Y} ${p2(h)}:${p2(mi)}:${p2(s)}`, `${M + 1}/${D}/${String(Y).slice(2)}`,
      `${mon[M]} ${D} ${Y}`, `${mon[M]} ${D}, ${Y}`, `${monL[M]} ${D}, ${Y}`, `${monL[M]} ${D} ${Y}`, `${D} ${mon[M]} ${Y}`, `${D} ${monL[M]} ${Y}`,
      `${mon[M]} ${p2(D)} ${Y} ${time}`, `${dow[w]} ${mon[M]} ${p2(D)} ${Y}`, `${dow[w]} ${mon[M]} ${p2(D)} ${Y} ${time}`,
      `${dow[w]} ${mon[M]} ${p2(D)} ${Y} ${time} GMT+0000`, `${dow[w]}, ${p2(D)} ${mon[M]} ${Y} ${time} GMT`, `${dowL[w]}, ${monL[M]} ${D}, ${Y}`,
      `${mon[M]} ${D}, ${Y} ${h % 12 || 12}:${p2(mi)} ${h >= 12 ? 'PM' : 'AM'}`, `${monL[M]} ${D}, ${Y} ${h % 12 || 12}:${p2(mi)}:${p2(s)} ${h >= 12 ? 'pm' : 'am'}`,
      `${mon[M].toUpperCase()} ${D} ${Y}`, `${mon[M].toLowerCase()} ${D} ${Y}`, `${mon[M]}-${D}-${Y}`, `${D}-${mon[M]}-${Y}`, `${M + 1}-${D}-${Y}`,
      `${mon[M]} ${Y}`, `${mon[M]} ${D}`, `${Y}-${p2(M + 1)}-${p2(D)}T${time}+00:00`, `${date}T24:00:00`, `${date}T${time}.5`, `${date}T${time}.123456`,
    ]) dateStrings.add(x);
  }
  for (const x of [
    '', ' ', 'abc', 'not a date', '2020-13-01', '2020-02-30', '2020-02-29', '2021-02-29', '2020-1-1', '2020-01-1', '20200101', '2020-01-01T25:00', '2020-01-01T10:60',
    '+002020-01-01', '-000001-01-01T00:00:00Z', '0000-01-01', '0001-01-01', '99-01-01', '1/1/49', '1/1/50', '1/1/99', '1/1/00', '12/31/1999', '31/12/1999', '0/1/2000',
    'Jan 32 2000', 'Foo 1 2000', 'Jan 1', '2000', '2000-01', '1e3', '12345', 'Tue Mar 01 2022 00:00:00 GMT+0100 (CET)', '2000-01-01T00:00:00 GMT', 'Jan 1 2000 UTC',
    'Jan 1 2000 10:00 UTC', 'Jan 1 2000 10:00 EST', 'Jan 1 2000 10:00 PST', '2000-01-01 10:00 PM', '10:00', '10:00:00', 'Z', 'T10:00',
  ]) dateStrings.add(x);
  for (const s of dateStrings) lines.push(`todate|${escLine(s)}|${hex16(Date.parse(s))}`);

  return { fixtures: { valuecases: { cases: lines.join('\n') } } };
}
