// Downloads the official Vega-Lite example specifications (the tag that matches the pinned vega-lite version)
// into scripts/.cache. Used by the fixture and gallery generators.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const version = JSON.parse(fs.readFileSync(new URL('./package.json', import.meta.url), 'utf8')).dependencies['vega-lite'];
const cache = path.join(path.dirname(fileURLToPath(import.meta.url)), '.cache');
const target = path.join(cache, `vega-lite-${version}`, 'examples', 'specs');
if (fs.existsSync(target)) {
  console.log(`examples already in ${target}`);
  process.exit(0);
}
fs.mkdirSync(cache, { recursive: true });
const archive = path.join(cache, 'vega-lite.tgz');
const url = `https://github.com/vega/vega-lite/archive/refs/tags/v${version}.tar.gz`;
console.log(`downloading ${url}`);
const res = await fetch(url);
if (!res.ok) throw new Error(`download failed: ${res.status}`);
fs.writeFileSync(archive, Buffer.from(await res.arrayBuffer()));
execFileSync('tar', ['-xzf', archive, '-C', cache, `vega-lite-${version}/examples/specs`], { stdio: 'inherit' });
console.log(`extracted to ${target}`);
