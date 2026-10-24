// Generates MoonBit fixture packages under ../fixtures from the official vega-lite / vega packages.
// Usage: cd scripts && npm ci && npm run fixtures
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { writeFixturePackage } from './lib/mbt.mjs';

// Fixtures must be generated with a fixed timezone: vega treats "local" time as the process timezone.
if (process.env.TZ !== 'UTC') {
  process.env.TZ = 'UTC';
}
if (new Date(2020, 5, 15, 12).getTimezoneOffset() !== 0) {
  console.error('error: process timezone is not UTC; run with TZ=UTC');
  process.exit(1);
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const only = process.argv.slice(2);
const generators = ['numfmt'];

for (const name of generators) {
  if (only.length && !only.includes(name)) continue;
  const { generate } = await import(`./gen/${name}.mjs`);
  const out = await generate();
  for (const [area, constants] of Object.entries(out)) {
    const dir = writeFixturePackage(root, area, constants);
    console.log(`wrote ${path.relative(root, dir)}`);
  }
}
