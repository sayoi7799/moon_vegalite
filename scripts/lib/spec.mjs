// Loading Vega-Lite specs for the official pipeline: `data.url` is replaced by inline values read from the
// vega-datasets package, so the official compiler and moon_vegalite see exactly the same input.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as vega from 'vega';

const datasetsDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'node_modules', 'vega-datasets', 'data');

export function readDataFile(url) {
  const name = url.replace(/^.*\/data\//, '').replace(/^data\//, '');
  const file = path.join(datasetsDir, name);
  const text = fs.readFileSync(file, 'utf8');
  const ext = path.extname(file).slice(1);
  if (ext === 'json') return JSON.parse(text);
  if (ext === 'csv' || ext === 'tsv') return vega.read(text, { type: ext });
  throw new Error(`unsupported data file type: ${url}`);
}

/** Replace every `data: {url}` by `data: {values}` (a deep copy is returned). */
export function inlineData(spec) {
  const out = JSON.parse(JSON.stringify(spec));
  const visit = (node) => {
    if (Array.isArray(node)) return node.forEach(visit);
    if (node && typeof node === 'object') {
      if (node.data && typeof node.data === 'object' && node.data.url) {
        const rows = readDataFile(node.data.url);
        const format = node.data.format && node.data.format.property ? node.data.format : undefined;
        let values = rows;
        if (format && format.property) values = format.property.split('.').reduce((o, k) => o[k], rows);
        node.data = { values };
      }
      Object.values(node).forEach(visit);
    }
  };
  visit(out);
  return out;
}

export function loadSpec(file) {
  return inlineData(JSON.parse(fs.readFileSync(file, 'utf8')));
}
